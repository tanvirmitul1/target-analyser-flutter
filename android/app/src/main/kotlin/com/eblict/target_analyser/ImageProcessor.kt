package com.eblict.target_analyser

import android.media.ExifInterface
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import org.opencv.core.*
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import java.io.File
import kotlin.math.PI
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * Full OpenCV target-analysis pipeline.
 *
 * Parts implemented (per spec):
 *  1. Resize → grayscale → Gaussian blur → adaptive threshold → morphological ops
 *  2. HoughCircles target detection → largest circle → ROI crop → perspective correction
 *  3. White-rectangle (centre zone) detection
 *  4. Multi-threshold bullet-hole detection (adaptive binary ∪ Canny)
 *  5. Precision improvements: CLAHE, normalisation, median blur, dynamic area thresholds
 *  6. JSON output (spec schema + legacy fields consumed by Dart model)
 *  8. Debug-mode annotations
 *
 * All [Mat] objects are released explicitly to avoid native heap leaks.
 */
class ImageProcessor {

    // ── Tuning ────────────────────────────────────────────────────────────────

    companion object {
        private const val TAG = "ImageProcessor"

        // Part 1 — resize
        private const val MAX_WIDTH = 720

        // Part 1 — Gaussian blur
        private const val GAUSS_SIGMA = 1.2

        // Part 1 — adaptive threshold
        private const val ADAPT_BLOCK = 21
        private const val ADAPT_C     = 5.0

        // Part 2 — HoughCircles
        private const val HC_DP      = 1.2
        private const val HC_PARAM1  = 100.0
        private const val HC_PARAM2  = 30.0

        // Part 3 — white-rectangle detection
        private const val WHITE_THRESH    = 200.0
        private const val WHITE_MIN_AREA  = 2000.0
        private const val WHITE_MIN_ASPECT = 0.8
        private const val WHITE_MAX_ASPECT = 1.5

        // Part 4 — shot contour filters
        private const val SHOT_MIN_PERIM         = 15.0
        private const val SHOT_CIRC_MIN          = 0.6
        private const val SHOT_CIRC_MAX          = 1.3
        private const val SHOT_MAX_ASPECT_RATIO  = 1.5
        private const val SHOT_BORDER_MARGIN     = 5
        private const val SHOT_WHITE_EXCLUSION   = 15.0  // px, skip if ≤ from white centre
        private const val SHOT_MERGE_DIST        = 10.0  // px

        // Part 5 — dynamic area thresholds (fraction of image area)
        private const val AREA_FRAC_MIN = 0.0005
        private const val AREA_FRAC_MAX = 0.01
    }

    // ── Internal data classes ─────────────────────────────────────────────────

    private data class TargetGeometry(
        val centre: Point,
        val radius: Double,
        val circlesDetected: Int,
    )

    /**
     * Holds the cropped (and possibly perspective-corrected) Mats.
     * All three image Mats are owned by this object — callers must release them.
     * [perspM] is the forward perspective transform if correction was applied
     * (needed to map local→global), otherwise null.
     */
    private data class CropResult(
        val img: Mat,
        val binary: Mat,
        val blurred: Mat,
        val roiRect: Rect,
        val perspM: Mat?,
    )

    // ── Public entry point ────────────────────────────────────────────────────

    /**
     * @param imagePath  Absolute path to source JPEG.
     * @param outputDir  Directory where the annotated result is saved.
     * @param debugMode  When true, extra annotations are drawn and logged.
     * @return JSON string — see [buildJson] for schema.
     * @throws IllegalStateException if the image cannot be decoded.
     */
    fun process(imagePath: String, outputDir: String, debugMode: Boolean = false): String {
        val t0  = System.currentTimeMillis()
        Log.i(TAG, "process() start  path=$imagePath  debug=$debugMode")

        var src = Imgcodecs.imread(imagePath)
        check(!src.empty()) { "Cannot decode image: $imagePath" }

        // Correct EXIF orientation — Android camera saves portrait images with a
        // rotation tag; OpenCV imread() ignores it, causing coordinates to shift.
        src = correctExifRotation(src, imagePath)

        return try {
            doProcess(src, outputDir, debugMode, t0)
        } finally {
            src.release()
        }
    }

    private fun correctExifRotation(src: Mat, imagePath: String): Mat {
        val orientation = try {
            ExifInterface(imagePath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (e: Exception) {
            Log.w(TAG, "Could not read EXIF orientation: ${e.message}")
            ExifInterface.ORIENTATION_NORMAL
        }
        val rotateCode = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90  -> Core.ROTATE_90_CLOCKWISE
            ExifInterface.ORIENTATION_ROTATE_180 -> Core.ROTATE_180
            ExifInterface.ORIENTATION_ROTATE_270 -> Core.ROTATE_90_COUNTERCLOCKWISE
            else -> return src
        }
        Log.d(TAG, "EXIF orientation=$orientation — applying rotation $rotateCode")
        val rotated = Mat()
        Core.rotate(src, rotated, rotateCode)
        src.release()
        return rotated
    }

    // ── Main pipeline ─────────────────────────────────────────────────────────

    private fun doProcess(src: Mat, outputDir: String, debugMode: Boolean, t0: Long): String {

        // ── Part 1 step 1: Resize to max 720 px width ─────────────────────────
        val scale = if (src.cols() > MAX_WIDTH) MAX_WIDTH.toDouble() / src.cols() else 1.0
        val resized = Mat()
        if (scale < 1.0) Imgproc.resize(src, resized, Size(), scale, scale, Imgproc.INTER_AREA)
        else src.copyTo(resized)
        val W = resized.cols()
        val H = resized.rows()
        Log.d(TAG, "Resized: ${W}×${H}  scale=${"%.3f".format(scale)}")

        // ── Part 1 step 2: Grayscale ──────────────────────────────────────────
        val gray = Mat()
        Imgproc.cvtColor(resized, gray, Imgproc.COLOR_BGR2GRAY)

        // ── Part 5: Normalise to 0–255 ────────────────────────────────────────
        Core.normalize(gray, gray, 0.0, 255.0, Core.NORM_MINMAX)

        // ── Part 5: CLAHE (clip=2.0, tile=8×8) ───────────────────────────────
        val clahe    = Imgproc.createCLAHE(2.0, Size(8.0, 8.0))
        val enhanced = Mat()
        clahe.apply(gray, enhanced)
        gray.release()

        // ── Part 5: Median blur 3×3 (noise reduction before threshold) ────────
        val medBlurred = Mat()
        Imgproc.medianBlur(enhanced, medBlurred, 3)
        enhanced.release()

        // ── Part 1 step 3: Gaussian blur 5×5 σ=1.2 ───────────────────────────
        val blurred = Mat()
        Imgproc.GaussianBlur(medBlurred, blurred, Size(5.0, 5.0), GAUSS_SIGMA)
        medBlurred.release()

        // ── Part 1 step 4: Adaptive threshold (shadow-robust) ─────────────────
        val binary = Mat()
        Imgproc.adaptiveThreshold(
            blurred, binary, 255.0,
            Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C,
            Imgproc.THRESH_BINARY_INV,
            ADAPT_BLOCK, ADAPT_C,
        )

        // ── Part 1 step 5: Morphological — ellipse 3×3, OPEN then DILATE ─────
        val kernel3 = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(3.0, 3.0))
        val morphed = Mat()
        Imgproc.morphologyEx(binary, morphed, Imgproc.MORPH_OPEN, kernel3)
        Imgproc.dilate(morphed, morphed, kernel3, Point(-1.0, -1.0), 1)
        binary.release()
        kernel3.release()

        // ── Part 2 step 1: HoughCircles for target boundary ───────────────────
        val circles = Mat()
        Imgproc.HoughCircles(
            blurred, circles,
            Imgproc.HOUGH_GRADIENT,
            HC_DP,
            H / 4.0,    // minDist  = rows / 4
            HC_PARAM1,
            HC_PARAM2,
            H / 6,      // minRadius = rows / 6
            H / 2,      // maxRadius = rows / 2
        )
        val geom = extractLargestCircle(circles, W, H)
        circles.release()
        Log.d(TAG, "Target → centre=${geom.centre}  radius=${geom.radius}  detected=${geom.circlesDetected}")

        // ── Part 2 step 2: Crop ROI + perspective correction ──────────────────
        val crop = cropAndCorrectPerspective(resized, morphed, blurred, geom.centre, geom.radius)
        morphed.release()
        blurred.release()

        // Centre coordinates in the crop/warp local space
        val rawLocalCentre = Point(geom.centre.x - crop.roiRect.x, geom.centre.y - crop.roiRect.y)
        val localCentre    = if (crop.perspM != null) transformPoint(rawLocalCentre, crop.perspM)
                             else rawLocalCentre

        // ── Part 3: White-rectangle centre detection ──────────────────────────
        val whiteLocal = detectWhiteCenter(crop.img, localCentre, geom.radius)
        Log.d(TAG, "White centre (local): $whiteLocal")

        // ── Part 4: Multi-threshold bullet-hole detection ─────────────────────
        val localShots = detectShots(
            crop.binary, crop.blurred,
            localCentre, geom.radius,
            whiteLocal, debugMode,
        )
        Log.d(TAG, "Shots (local, post-merge): ${localShots.size}")

        // ── Convert local → full-image coordinates ────────────────────────────
        val globalShots  = localToGlobal(localShots, crop)
        val whiteGlobal  = localPointToGlobal(whiteLocal, crop)
        crop.img.release()
        crop.binary.release()
        crop.blurred.release()
        crop.perspM?.release()

        // ── Annotate resized image + save ─────────────────────────────────────
        val annotated = resized.clone()
        resized.release()

        drawAnnotations(annotated, geom.centre, geom.radius, whiteGlobal, globalShots, debugMode)

        val outPath = saveAnnotated(annotated, outputDir)
        annotated.release()

        val elapsed = System.currentTimeMillis() - t0
        Log.i(TAG, "process() done in ${elapsed} ms → ${globalShots.size} shot(s)")

        return buildJson(
            centre          = geom.centre,
            targetRadius    = geom.radius,
            shots           = globalShots,
            processedPath   = outPath,
            imageWidth      = W,
            imageHeight     = H,
            circlesDetected = geom.circlesDetected,
            elapsedMs       = elapsed,
        )
    }

    // ── Part 2 helper: select largest detected circle ─────────────────────────

    private fun extractLargestCircle(circles: Mat, W: Int, H: Int): TargetGeometry {
        if (!circles.empty() && circles.cols() > 0) {
            var bestIdx = 0
            var bestR   = -1.0
            for (i in 0 until circles.cols()) {
                val d = circles.get(0, i)!!
                if (d[2] > bestR) { bestR = d[2]; bestIdx = i }
            }
            val d = circles.get(0, bestIdx)!!
            return TargetGeometry(
                centre          = Point(d[0], d[1]),
                radius          = d[2],
                circlesDetected = circles.cols(),
            )
        }
        Log.w(TAG, "HoughCircles: no circles — using image-centre fallback")
        return TargetGeometry(
            centre          = Point(W / 2.0, H / 2.0),
            radius          = min(W, H) * 0.40,
            circlesDetected = 0,
        )
    }

    // ── Part 2: Crop ROI + perspective correction ─────────────────────────────

    private fun cropAndCorrectPerspective(
        src: Mat, binary: Mat, blurred: Mat,
        centre: Point, radius: Double,
    ): CropResult {
        val x0  = (centre.x - radius).toInt().coerceAtLeast(0)
        val y0  = (centre.y - radius).toInt().coerceAtLeast(0)
        val x1  = (centre.x + radius).toInt().coerceAtMost(src.cols() - 1)
        val y1  = (centre.y + radius).toInt().coerceAtMost(src.rows() - 1)
        val roi = Rect(x0, y0, (x1 - x0).coerceAtLeast(1), (y1 - y0).coerceAtLeast(1))

        val croppedSrc    = Mat(src,    roi).clone()
        val croppedBinary = Mat(binary, roi).clone()
        val croppedBlur   = Mat(blurred, roi).clone()

        // Try to find the target-card boundary as a quadrilateral.
        val edged = Mat()
        Imgproc.Canny(croppedBlur, edged, 50.0, 150.0)

        val contours  = ArrayList<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(
            edged, contours, hierarchy,
            Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE,
        )
        edged.release()
        hierarchy.release()

        val largest = contours.maxByOrNull { Imgproc.contourArea(it) }
        if (largest != null) {
            val largestF = MatOfPoint2f(*largest.toArray())
            val peri     = Imgproc.arcLength(largestF, true)
            val approx   = MatOfPoint2f()
            Imgproc.approxPolyDP(largestF, approx, 0.02 * peri, true)
            largestF.release()

            if (approx.rows() == 4) {
                Log.d(TAG, "Perspective correction: 4-pt contour detected")
                val dstW       = roi.width.toDouble()
                val dstH       = roi.height.toDouble()
                val orderedSrc = orderPoints(approx.toArray())
                val orderedDst = MatOfPoint2f(
                    Point(0.0,       0.0),
                    Point(dstW - 1,  0.0),
                    Point(dstW - 1,  dstH - 1),
                    Point(0.0,       dstH - 1),
                )
                val M       = Imgproc.getPerspectiveTransform(orderedSrc, orderedDst)
                val dstSize = Size(dstW, dstH)
                val wSrc    = Mat(); val wBin = Mat(); val wBlur = Mat()
                Imgproc.warpPerspective(croppedSrc,    wSrc,  M, dstSize)
                Imgproc.warpPerspective(croppedBinary, wBin,  M, dstSize)
                Imgproc.warpPerspective(croppedBlur,   wBlur, M, dstSize)
                orderedSrc.release(); orderedDst.release(); approx.release()
                croppedSrc.release(); croppedBinary.release(); croppedBlur.release()
                contours.forEach { it.release() }
                return CropResult(wSrc, wBin, wBlur, roi, M)
            }
            approx.release()
        }
        contours.forEach { it.release() }
        return CropResult(croppedSrc, croppedBinary, croppedBlur, roi, null)
    }

    /** Orders four points as [TL, TR, BR, BL]. */
    private fun orderPoints(pts: Array<Point>): MatOfPoint2f {
        val idx    = pts.indices.toList()
        val bySum  = idx.sortedBy { pts[it].x + pts[it].y }
        val tlI    = bySum.first();  val brI = bySum.last()
        val rem    = idx.filter { it != tlI && it != brI }
        val trI    = rem.minByOrNull { pts[it].y - pts[it].x }!!
        val blI    = rem.maxByOrNull { pts[it].y - pts[it].x }!!
        return MatOfPoint2f(pts[tlI], pts[trI], pts[brI], pts[blI])
    }

    // ── Part 3: White-rectangle centre detection ──────────────────────────────

    private fun detectWhiteCenter(img: Mat, fallback: Point, radius: Double): Point {
        val gray = Mat()
        if (img.channels() >= 3) Imgproc.cvtColor(img, gray, Imgproc.COLOR_BGR2GRAY)
        else img.copyTo(gray)

        val bright = Mat()
        Imgproc.threshold(gray, bright, WHITE_THRESH, 255.0, Imgproc.THRESH_BINARY)
        gray.release()

        val contours  = ArrayList<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(
            bright, contours, hierarchy,
            Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE,
        )
        bright.release(); hierarchy.release()

        // Re-compute grayscale for mean-brightness scoring
        val grayMean = Mat()
        if (img.channels() >= 3) Imgproc.cvtColor(img, grayMean, Imgproc.COLOR_BGR2GRAY)
        else img.copyTo(grayMean)

        var bestScore  = -1.0
        var bestCentre = fallback

        for (c in contours) {
            val area = Imgproc.contourArea(c)
            if (area < WHITE_MIN_AREA) continue

            val rect   = Imgproc.boundingRect(c)
            val aspect = rect.width.toDouble() / rect.height.coerceAtLeast(1)
            if (aspect < WHITE_MIN_ASPECT || aspect > WHITE_MAX_ASPECT) continue

            // Mean brightness inside this contour
            val mask = Mat.zeros(img.rows(), img.cols(), CvType.CV_8UC1)
            Imgproc.drawContours(mask, listOf(c), -1, Scalar(255.0), Core.FILLED)
            val meanBright = Core.mean(grayMean, mask).`val`[0]
            mask.release()

            if (meanBright > bestScore) {
                bestScore = meanBright
                val m = Imgproc.moments(c)
                if (m.m00 != 0.0) bestCentre = Point(m.m10 / m.m00, m.m01 / m.m00)
            }
        }
        grayMean.release()
        contours.forEach { it.release() }
        return bestCentre
    }

    // ── Part 4: Multi-threshold shot detection ────────────────────────────────

    private fun detectShots(
        binary: Mat,
        blurred: Mat,
        localCentre: Point,
        radius: Double,
        whiteCenter: Point,
        debugMode: Boolean,
    ): List<Point> {
        val imageArea = binary.rows().toDouble() * binary.cols()
        val minArea   = max(20.0, AREA_FRAC_MIN * imageArea)
        val maxArea   = min(500.0, AREA_FRAC_MAX * imageArea)
        Log.d(TAG, "Shot area window: [${"%.1f".format(minArea)}, ${"%.1f".format(maxArea)}]")

        // Circular mask — restrict analysis to target disc
        val circleMask = Mat.zeros(binary.size(), CvType.CV_8UC1)
        Imgproc.circle(circleMask, localCentre, radius.toInt(), Scalar(255.0), Core.FILLED)

        // ── Path A: morphed adaptive binary ──────────────────────────────────
        val maskedA = Mat()
        Core.bitwise_and(binary, circleMask, maskedA)

        // ── Path B: Canny (50, 150) + dilate ─────────────────────────────────
        val canny  = Mat()
        Imgproc.Canny(blurred, canny, 50.0, 150.0)
        val kDilate = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(3.0, 3.0))
        Imgproc.dilate(canny, canny, kDilate)
        kDilate.release()
        val maskedB = Mat()
        Core.bitwise_and(canny, circleMask, maskedB)
        canny.release()
        circleMask.release()

        // ── Union A ∪ B ───────────────────────────────────────────────────────
        val unionMat = Mat()
        Core.bitwise_or(maskedA, maskedB, unionMat)
        maskedA.release(); maskedB.release()

        // ── Find contours ─────────────────────────────────────────────────────
        val contours  = ArrayList<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(
            unionMat, contours, hierarchy,
            Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE,
        )
        unionMat.release(); hierarchy.release()

        val candidates = mutableListOf<Point>()

        for (c in contours) {
            // ── Area ─────────────────────────────────────────────────────────
            val area = Imgproc.contourArea(c)
            if (area < minArea || area > maxArea) continue

            // ── Perimeter ─────────────────────────────────────────────────────
            val cF   = MatOfPoint2f(*c.toArray())
            val peri = Imgproc.arcLength(cF, true)
            cF.release()
            if (peri < SHOT_MIN_PERIM) continue

            // ── Circularity  4πA / P² ─────────────────────────────────────────
            val circ = (4.0 * PI * area) / (peri * peri)
            if (circ < SHOT_CIRC_MIN || circ > SHOT_CIRC_MAX) continue

            // ── Bounding-box aspect ratio ──────────────────────────────────────
            val rect   = Imgproc.boundingRect(c)
            val aspect = rect.width.toDouble() / rect.height.coerceAtLeast(1)
            if (aspect > SHOT_MAX_ASPECT_RATIO || aspect < 1.0 / SHOT_MAX_ASPECT_RATIO) continue

            // ── Centroid ──────────────────────────────────────────────────────
            val mom = Imgproc.moments(c)
            if (mom.m00 == 0.0) continue
            val cx = mom.m10 / mom.m00
            val cy = mom.m01 / mom.m00

            // ── Not too close to border ────────────────────────────────────────
            if (cx < SHOT_BORDER_MARGIN || cy < SHOT_BORDER_MARGIN ||
                cx > binary.cols() - SHOT_BORDER_MARGIN ||
                cy > binary.rows() - SHOT_BORDER_MARGIN) continue

            // ── Must be inside the target circle ──────────────────────────────
            if (hypot(cx - localCentre.x, cy - localCentre.y) > radius) continue

            // ── Not inside white-rectangle centre zone ─────────────────────────
            if (hypot(cx - whiteCenter.x, cy - whiteCenter.y) < SHOT_WHITE_EXCLUSION) continue

            candidates += Point(cx, cy)
        }
        contours.forEach { it.release() }

        if (debugMode) Log.d(TAG, "Candidates before merge: ${candidates.size}")
        return mergeClose(candidates, SHOT_MERGE_DIST)
    }

    /** Merges points closer than [threshold] px by averaging their positions. */
    private fun mergeClose(pts: List<Point>, threshold: Double): List<Point> {
        val used   = BooleanArray(pts.size)
        val result = mutableListOf<Point>()
        for (i in pts.indices) {
            if (used[i]) continue
            var sx = pts[i].x; var sy = pts[i].y; var n = 1
            for (j in i + 1 until pts.size) {
                if (!used[j] && hypot(pts[i].x - pts[j].x, pts[i].y - pts[j].y) < threshold) {
                    sx += pts[j].x; sy += pts[j].y; n++; used[j] = true
                }
            }
            result += Point(sx / n, sy / n)
        }
        return result
    }

    // ── Coordinate-transform helpers ──────────────────────────────────────────

    private fun transformPoint(pt: Point, M: Mat): Point {
        val src = MatOfPoint2f(pt)
        val dst = MatOfPoint2f()
        Core.perspectiveTransform(src, dst, M)
        val r = dst.toArray()[0]
        src.release(); dst.release()
        return r
    }

    private fun localToGlobal(pts: List<Point>, crop: CropResult): List<Point> {
        if (pts.isEmpty()) return emptyList()
        return if (crop.perspM != null) {
            val invM = Mat()
            Core.invert(crop.perspM, invM)
            val result = pts.map {
                val t = transformPoint(it, invM)
                Point(t.x + crop.roiRect.x, t.y + crop.roiRect.y)
            }
            invM.release()
            result
        } else {
            pts.map { Point(it.x + crop.roiRect.x, it.y + crop.roiRect.y) }
        }
    }

    private fun localPointToGlobal(pt: Point, crop: CropResult): Point =
        localToGlobal(listOf(pt), crop).first()

    // ── Part 8: Annotations ───────────────────────────────────────────────────

    private fun drawAnnotations(
        dst: Mat,
        centre: Point,
        radius: Double,
        whiteCenter: Point,
        shots: List<Point>,
        debugMode: Boolean,
    ) {
        val iR    = radius.toInt()
        val green = Scalar(0.0, 230.0, 0.0)
        val grey  = Scalar(200.0, 200.0, 200.0)
        val cyan  = Scalar(255.0, 220.0, 0.0)
        val red   = Scalar(0.0,   0.0,   255.0)
        val lime  = Scalar(0.0,   255.0, 100.0)

        // Target boundary circle
        Imgproc.circle(dst, centre, iR, green, 3)

        // Guide rings at 20 % intervals
        for (f in listOf(0.2, 0.4, 0.6, 0.8))
            Imgproc.circle(dst, centre, (radius * f).toInt(), grey, 1)

        // Detected white-rectangle centre (cyan crosshair)
        val arm = (radius * 0.06).toInt().coerceAtLeast(8)
        Imgproc.line(dst, Point(whiteCenter.x - arm, whiteCenter.y), Point(whiteCenter.x + arm, whiteCenter.y), cyan, 2)
        Imgproc.line(dst, Point(whiteCenter.x, whiteCenter.y - arm), Point(whiteCenter.x, whiteCenter.y + arm), cyan, 2)
        Imgproc.circle(dst, whiteCenter, 5, cyan, Core.FILLED)

        // Geometric centre of detected circle (lime, thin)
        val cross = (radius * 0.08).toInt().coerceAtLeast(10)
        Imgproc.line(dst, Point(centre.x - cross, centre.y), Point(centre.x + cross, centre.y), lime, 1)
        Imgproc.line(dst, Point(centre.x, centre.y - cross), Point(centre.x, centre.y + cross), lime, 1)

        // Shot holes
        shots.forEachIndexed { i, shot ->
            Imgproc.circle(dst, shot, 18, red,  2)
            Imgproc.circle(dst, shot,  5, lime, Core.FILLED)
            Imgproc.putText(
                dst, "${i + 1}",
                Point(shot.x + 22.0, shot.y - 12.0),
                Imgproc.FONT_HERSHEY_SIMPLEX, 0.9,
                Scalar(0.0, 220.0, 255.0), 2,
            )
        }

        // Extra debug overlays
        if (debugMode) {
            Imgproc.circle(dst, centre, 8, red, Core.FILLED)
            Imgproc.putText(
                dst,
                "r=${"%.0f".format(radius)} shots=${shots.size}",
                Point((centre.x + 12).coerceAtMost(dst.cols() - 120.0), centre.y - 12),
                Imgproc.FONT_HERSHEY_SIMPLEX, 0.65,
                Scalar(0.0, 200.0, 255.0), 2,
            )
        }
    }

    // ── Save annotated image ──────────────────────────────────────────────────

    private fun saveAnnotated(image: Mat, outputDir: String): String {
        val dir     = File(outputDir, "opencv_processed")
        dir.mkdirs()
        val outFile = File(dir, "result_${System.currentTimeMillis()}.jpg")
        val params  = MatOfInt(Imgcodecs.IMWRITE_JPEG_QUALITY, 90)
        return if (Imgcodecs.imwrite(outFile.absolutePath, image, params)) {
            Log.i(TAG, "Saved annotated image: ${outFile.absolutePath}")
            outFile.absolutePath
        } else {
            Log.e(TAG, "imwrite() failed — annotated image NOT saved")
            ""
        }
    }

    // ── Part 6: JSON output ───────────────────────────────────────────────────

    private fun buildJson(
        centre: Point,
        targetRadius: Double,
        shots: List<Point>,
        processedPath: String,
        imageWidth: Int,
        imageHeight: Int,
        circlesDetected: Int,
        elapsedMs: Long,
    ): String = JSONObject().apply {
        // ── Spec schema (Part 6) ──────────────────────────────────────────────
        put("center", JSONObject().apply {
            put("x", centre.x)
            put("y", centre.y)
        })
        put("shots", JSONArray().apply {
            shots.forEach { s ->
                put(JSONObject().apply { put("x", s.x); put("y", s.y) })
            }
        })
        put("meta", JSONObject().apply {
            put("totalShots", shots.size)
        })

        // ── Extended fields consumed by the Dart OpenCvResult model ───────────
        put("target_radius",        targetRadius)
        put("processed_image_path", processedPath)
        put("debug", JSONObject().apply {
            put("circles_detected",   circlesDetected)
            put("shots_found",        shots.size)
            put("image_width",        imageWidth)
            put("image_height",       imageHeight)
            put("processing_time_ms", elapsedMs)
        })
    }.toString()
}
