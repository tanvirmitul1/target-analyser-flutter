package com.eblict.target_analyser

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import org.opencv.core.*
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import java.io.File
import kotlin.math.PI
import kotlin.math.min

/**
 * Performs target-analysis image processing using OpenCV.
 *
 * Pipeline:
 *  1. Load JPEG via [Imgcodecs.imread].
 *  2. Convert to grayscale + apply CLAHE for contrast normalisation.
 *  3. [Imgproc.HoughCircles] to locate the target boundary.
 *  4. Adaptive threshold + contour analysis to detect shot holes.
 *  5. Annotate and save the result image.
 *  6. Return a JSON string matching the agreed schema.
 *
 * All [Mat] objects are explicitly [Mat.release]d to avoid native memory leaks.
 */
class ImageProcessor {

    companion object {
        private const val TAG = "ImageProcessor"

        // ── Shot-detection tuning ─────────────────────────────────────────────
        /** Minimum bullet-hole radius in pixels. */
        private const val MIN_SHOT_RADIUS_PX = 4.0

        /** Shot hole may not exceed this fraction of the target area. */
        private const val MAX_SHOT_AREA_FRACTION = 0.04

        // ── HoughCircles tuning ───────────────────────────────────────────────
        private const val HC_DP          = 1.0
        private const val HC_CANNY_HIGH  = 150.0
        private const val HC_ACCUM_THRESH = 40.0
    }

    // ── Public API ────────────────────────────────────────────────────────────

    /**
     * @param imagePath  Absolute path to the captured JPEG.
     * @param outputDir  Directory where the annotated image will be saved
     *                   (typically [Context.getCacheDir]).
     * @return           JSON string — see schema in [buildJson].
     * @throws [IllegalArgumentException] if the image cannot be loaded.
     */
    fun process(imagePath: String, outputDir: String): String {
        val t0 = System.currentTimeMillis()
        Log.i(TAG, "Processing: $imagePath")

        // ── 1. Load ───────────────────────────────────────────────────────────
        val src = Imgcodecs.imread(imagePath)
        check(!src.empty()) { "Could not load image: $imagePath" }

        val W = src.cols()
        val H = src.rows()
        Log.d(TAG, "Image size: ${W}×${H}")

        try {
            // ── 2. Prepare grayscale with contrast enhancement ────────────────
            val gray = Mat()
            Imgproc.cvtColor(src, gray, Imgproc.COLOR_BGR2GRAY)

            val enhanced = Mat()
            val clahe = Imgproc.createCLAHE(3.0, Size(8.0, 8.0))
            clahe.apply(gray, enhanced)
            gray.release()

            val blurred = Mat()
            Imgproc.GaussianBlur(enhanced, blurred, Size(9.0, 9.0), 2.0)

            // ── 3. Detect target boundary (HoughCircles) ──────────────────────
            val circles = Mat()
            Imgproc.HoughCircles(
                blurred, circles,
                Imgproc.HOUGH_GRADIENT,
                HC_DP,
                H / 8.0,          // minDist between circle centres
                HC_CANNY_HIGH,
                HC_ACCUM_THRESH,
                H / 8,            // minRadius
                H / 2,            // maxRadius
            )
            blurred.release()

            val (targetCentre, targetRadius, circlesDetected) =
                extractTargetGeometry(circles, W, H)
            circles.release()

            Log.d(TAG, "Target: centre=$targetCentre radius=$targetRadius detected=$circlesDetected")

            // ── 4. Detect shot holes ──────────────────────────────────────────
            val shots = detectShots(enhanced, targetCentre, targetRadius)
            enhanced.release()

            Log.d(TAG, "Shots found: ${shots.size}")

            // ── 5. Annotate + save ────────────────────────────────────────────
            val annotated = src.clone()
            drawAnnotations(annotated, targetCentre, targetRadius, shots)
            val outputPath = saveAnnotated(annotated, outputDir)
            annotated.release()

            val elapsedMs = System.currentTimeMillis() - t0

            return buildJson(
                centre          = targetCentre,
                targetRadius    = targetRadius,
                shots           = shots,
                processedPath   = outputPath,
                imageWidth      = W,
                imageHeight     = H,
                circlesDetected = circlesDetected,
                elapsedMs       = elapsedMs,
            )
        } finally {
            src.release()
        }
    }

    // ── Step 3 helper: target geometry ────────────────────────────────────────

    private data class TargetGeometry(
        val centre: Point,
        val radius: Double,
        val circlesDetected: Int,
    )

    private fun extractTargetGeometry(circles: Mat, W: Int, H: Int): TargetGeometry {
        if (!circles.empty() && circles.cols() > 0) {
            // HoughCircles returns a 1×N matrix of (x, y, r) triplets.
            val bestCircle = circles.get(0, 0)!!
            return TargetGeometry(
                centre          = Point(bestCircle[0], bestCircle[1]),
                radius          = bestCircle[2],
                circlesDetected = circles.cols(),
            )
        }
        // Fallback: treat image centre as target centre, 40 % of short edge as radius.
        Log.w(TAG, "HoughCircles found no circles — using image-centre fallback.")
        return TargetGeometry(
            centre          = Point(W / 2.0, H / 2.0),
            radius          = min(W, H) * 0.40,
            circlesDetected = 0,
        )
    }

    // ── Step 4: shot-hole detection ───────────────────────────────────────────

    private fun detectShots(enhanced: Mat, centre: Point, radius: Double): List<Point> {
        // Circular mask — only look inside the target area.
        val mask = Mat.zeros(enhanced.size(), CvType.CV_8UC1)
        Imgproc.circle(mask, centre, radius.toInt(), Scalar(255.0), Core.FILLED)

        // Adaptive threshold (inverted) finds dark regions (bullet holes).
        val binary = Mat()
        Imgproc.adaptiveThreshold(
            enhanced, binary, 255.0,
            Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C,
            Imgproc.THRESH_BINARY_INV,
            /* blockSize = */ 11,
            /* C         = */ 5.0,
        )

        // Apply circular mask.
        val masked = Mat()
        Core.bitwise_and(binary, mask, masked)
        binary.release()
        mask.release()

        // Morphological open (removes speckle) then close (fills holes in bullet holes).
        val kernel = Imgproc.getStructuringElement(
            Imgproc.MORPH_ELLIPSE, Size(5.0, 5.0)
        )
        val cleaned = Mat()
        Imgproc.morphologyEx(masked, cleaned, Imgproc.MORPH_OPEN,  kernel)
        Imgproc.morphologyEx(cleaned, cleaned, Imgproc.MORPH_CLOSE, kernel)
        masked.release()

        // Contour analysis.
        val contours   = ArrayList<MatOfPoint>()
        val hierarchy  = Mat()
        Imgproc.findContours(
            cleaned, contours, hierarchy,
            Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE,
        )
        cleaned.release()
        hierarchy.release()

        val minArea = PI * MIN_SHOT_RADIUS_PX * MIN_SHOT_RADIUS_PX
        val maxArea = PI * radius * radius * MAX_SHOT_AREA_FRACTION

        val shots = mutableListOf<Point>()
        for (contour in contours) {
            val area = Imgproc.contourArea(contour)
            if (area < minArea || area > maxArea) continue

            val m = Imgproc.moments(contour)
            if (m.m00 == 0.0) continue

            shots += Point(m.m10 / m.m00, m.m01 / m.m00)
        }

        return shots
    }

    // ── Step 5a: draw annotations ─────────────────────────────────────────────

    private fun drawAnnotations(
        dst: Mat,
        centre: Point,
        radius: Double,
        shots: List<Point>,
    ) {
        // Target boundary.
        Imgproc.circle(dst, centre, radius.toInt(), Scalar(0.0, 230.0, 0.0), 3)

        // Guide rings at 20 % intervals.
        val ringColor = Scalar(200.0, 200.0, 200.0)
        for (factor in listOf(0.2, 0.4, 0.6, 0.8)) {
            Imgproc.circle(dst, centre, (radius * factor).toInt(), ringColor, 1)
        }

        // Crosshair at centre.
        val cross = (radius * 0.08).toInt().coerceAtLeast(10)
        val cyan  = Scalar(255.0, 220.0, 0.0)
        Imgproc.line(dst, Point(centre.x - cross, centre.y), Point(centre.x + cross, centre.y), cyan, 2)
        Imgproc.line(dst, Point(centre.x, centre.y - cross), Point(centre.x, centre.y + cross), cyan, 2)
        Imgproc.circle(dst, centre, 6, cyan, Core.FILLED)

        // Shot holes.
        shots.forEachIndexed { i, shot ->
            // Red outline ring.
            Imgproc.circle(dst, shot, 18, Scalar(0.0, 0.0, 255.0), 2)
            // Green fill dot.
            Imgproc.circle(dst, shot, 5, Scalar(0.0, 255.0, 0.0), Core.FILLED)
            // Yellow label.
            Imgproc.putText(
                dst,
                "${i + 1}",
                Point(shot.x + 22.0, shot.y - 12.0),
                Imgproc.FONT_HERSHEY_SIMPLEX,
                /* fontScale = */ 0.9,
                Scalar(0.0, 220.0, 255.0),
                /* thickness = */ 2,
            )
        }
    }

    // ── Step 5b: save to disk ─────────────────────────────────────────────────

    private fun saveAnnotated(image: Mat, outputDir: String): String {
        val dir = File(outputDir, "opencv_processed")
        dir.mkdirs()

        val outFile = File(dir, "result_${System.currentTimeMillis()}.jpg")
        val params  = MatOfInt(Imgcodecs.IMWRITE_JPEG_QUALITY, 90)
        val saved   = Imgcodecs.imwrite(outFile.absolutePath, image, params)

        return if (saved) {
            Log.i(TAG, "Annotated image saved: ${outFile.absolutePath}")
            outFile.absolutePath
        } else {
            Log.e(TAG, "imwrite failed — annotated image NOT saved.")
            ""
        }
    }

    // ── JSON builder ──────────────────────────────────────────────────────────

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
        put("center", JSONObject().apply {
            put("x", centre.x)
            put("y", centre.y)
        })
        put("target_radius", targetRadius)
        put("processed_image_path", processedPath)
        put("shots", JSONArray().apply {
            shots.forEach { shot ->
                put(JSONObject().apply {
                    put("x", shot.x)
                    put("y", shot.y)
                })
            }
        })
        put("debug", JSONObject().apply {
            put("circles_detected",   circlesDetected)
            put("shots_found",        shots.size)
            put("image_width",        imageWidth)
            put("image_height",       imageHeight)
            put("processing_time_ms", elapsedMs)
        })
    }.toString()
}
