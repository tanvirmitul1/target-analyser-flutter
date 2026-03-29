package com.eblict.target_analyser

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.core.Core
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * Entry point for the Flutter host on Android.
 *
 * Responsibilities:
 *  1. Initialise OpenCV via [OpenCVLoader.initLocal] (bundles native .so — no
 *     external OpenCV Manager app required).
 *  2. Register the [CHANNEL] [MethodChannel] and dispatch calls to
 *     [ImageProcessor] on a dedicated background thread.
 *  3. Marshal results / errors back to the Flutter engine on the main thread.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG     = "MainActivity"
        private const val CHANNEL = "image_processor"
    }

    // Single-threaded executor keeps processing jobs sequential and avoids
    // overwhelming memory with concurrent Mat allocations.
    private val processingExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "opencv-worker").apply { isDaemon = true }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    // Null until OpenCV initialises successfully.
    private var imageProcessor: ImageProcessor? = null

    // ── Flutter engine ────────────────────────────────────────────────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initOpenCv()
        registerMethodChannel(flutterEngine)
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onDestroy() {
        processingExecutor.shutdown()
        super.onDestroy()
    }

    // ── OpenCV initialisation ─────────────────────────────────────────────────

    private fun initOpenCv() {
        // initLocal() loads the native library bundled via the Maven artifact.
        // Must be called on the main thread before any org.opencv.* usage.
        if (OpenCVLoader.initLocal()) {
            Log.i(TAG, "OpenCV ${Core.VERSION} initialised successfully.")
            imageProcessor = ImageProcessor()
        } else {
            Log.e(TAG, "OpenCV initialisation FAILED — image_processor channel will return errors.")
        }
    }

    // ── MethodChannel registration ────────────────────────────────────────────

    private fun registerMethodChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "processImage" -> handleProcessImage(call, result)
                    else           -> result.notImplemented()
                }
            }
    }

    // ── Handler: processImage ─────────────────────────────────────────────────

    private fun handleProcessImage(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        // Guard: OpenCV must be ready.
        val processor = imageProcessor ?: run {
            result.error(
                "OPENCV_NOT_READY",
                "OpenCV failed to initialise — check logcat for details.",
                null,
            )
            return
        }

        // Validate required argument.
        val imagePath = call.argument<String>("path")
        if (imagePath.isNullOrBlank()) {
            result.error(
                "INVALID_ARGS",
                "Required argument 'path' is missing or empty.",
                null,
            )
            return
        }

        val debugMode = call.argument<Boolean>("debugMode") ?: false

        // Dispatch to background thread.
        val outputDir = cacheDir.absolutePath
        try {
            processingExecutor.execute {
                runProcessing(processor, imagePath, outputDir, debugMode, result)
            }
        } catch (e: RejectedExecutionException) {
            result.error(
                "EXECUTOR_SHUTDOWN",
                "Processing executor is no longer accepting tasks.",
                null,
            )
        }
    }

    /**
     * Runs [ImageProcessor.process] on the worker thread; marshals the result
     * back to [result] on the main thread.
     *
     * [MethodChannel.Result] callbacks MUST be called on the main thread.
     */
    private fun runProcessing(
        processor: ImageProcessor,
        imagePath: String,
        outputDir: String,
        debugMode: Boolean,
        result: MethodChannel.Result,
    ) {
        try {
            val json = processor.process(imagePath, outputDir, debugMode)
            mainHandler.post { result.success(json) }
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "processImage — bad input: ${e.message}")
            mainHandler.post {
                result.error("INVALID_IMAGE", e.message, null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "processImage failed", e)
            mainHandler.post {
                result.error(
                    "PROCESSING_ERROR",
                    e.message ?: "Unknown error",
                    e.stackTraceToString(),
                )
            }
        }
    }
}
