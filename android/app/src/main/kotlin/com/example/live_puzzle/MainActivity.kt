package com.example.live_puzzle

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.*

class MainActivity: FlutterActivity() {
    private val LIVE_PHOTO_CHANNEL = "live_puzzle/live_photo"
    private val FRAME_EXTRACTOR_CHANNEL = "live_puzzle/frame_extractor"
    private val CREATOR_CHANNEL = "live_puzzle/creator"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Live Photo Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_PHOTO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isMotionPhoto" -> {
                        val assetId = call.argument<String>("assetId")
                        result.success(isMotionPhoto(assetId))
                    }
                    "extractMotionVideo" -> {
                        val assetId = call.argument<String>("assetId")
                        result.success(extractMotionVideo(assetId))
                    }
                    "getVideoDuration" -> {
                        val videoPath = call.argument<String>("videoPath")
                        result.success(getVideoDuration(videoPath))
                    }
                    "getVideoFrameCount" -> {
                        val videoPath = call.argument<String>("videoPath")
                        result.success(getVideoFrameCount(videoPath))
                    }
                    else -> result.notImplemented()
                }
            }

        // Frame Extractor Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FRAME_EXTRACTOR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractFrameAtTime" -> {
                        val videoPath = call.argument<String>("videoPath")
                        val timestamp = call.argument<Int>("timestamp") ?: 0
                        result.success(extractFrameAtTime(videoPath, timestamp.toLong()))
                    }
                    "extractFrameAtIndex" -> {
                        result.success(null)
                    }
                    "extractFrames" -> {
                        result.success(emptyList<Any>())
                    }
                    "extractKeyFrames" -> {
                        result.success(emptyList<Any>())
                    }
                    else -> result.notImplemented()
                }
            }

        // Creator Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CREATOR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "createVideoFromFrames" -> {
                        val framePaths = call.argument<List<String>>("framePaths")
                        val outputPath = call.argument<String>("outputPath")
                        val fps = call.argument<Int>("fps") ?: 30
                        result.success(createVideoFromFrames(framePaths, outputPath, fps))
                    }
                    "createMotionPhoto" -> {
                        val imagePath = call.argument<String>("imagePath")
                        val videoPath = call.argument<String>("videoPath")
                        val outputPath = call.argument<String>("outputPath")
                        result.success(createMotionPhoto(imagePath, videoPath, outputPath))
                    }
                    "saveToGallery" -> {
                        val filePath = call.argument<String>("filePath")
                        result.success(saveToGallery(filePath))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isMotionPhoto(assetId: String?): Boolean {
        if (assetId == null) return false
        // 简化实现：检查文件是否包含Motion Photo元数据
        // 实际应用中需要更复杂的检测逻辑
        return false
    }

    private fun extractMotionVideo(assetId: String?): String? {
        if (assetId == null) return null
        // Motion Photo通常是JPEG + 内嵌MP4
        // 这里需要解析JPEG文件，提取内嵌的MP4视频
        return null
    }

    private fun getVideoDuration(videoPath: String?): Int {
        if (videoPath == null) return 3000

        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(videoPath)
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            duration?.toInt() ?: 3000
        } catch (e: Exception) {
            3000
        } finally {
            retriever.release()
        }
    }

    private fun getVideoFrameCount(videoPath: String?): Int {
        if (videoPath == null) return 30

        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(videoPath)
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val frameRate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CAPTURE_FRAMERATE)
            
            val durationMs = duration?.toLong() ?: 3000L
            val fps = frameRate?.toFloat() ?: 30f
            
            ((durationMs / 1000.0) * fps).toInt()
        } catch (e: Exception) {
            30
        } finally {
            retriever.release()
        }
    }

    private fun extractFrameAtTime(videoPath: String?, timestamp: Long): Map<String, Any>? {
        if (videoPath == null) return null

        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(videoPath)
            val bitmap = retriever.getFrameAtTime(
                timestamp * 1000, // 转换为微秒
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            )

            if (bitmap != null) {
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 90, stream)
                val imageData = stream.toByteArray()

                mapOf(
                    "index" to 0,
                    "timestamp" to timestamp.toInt(),
                    "imageData" to imageData,
                    "width" to bitmap.width,
                    "height" to bitmap.height
                )
            } else {
                null
            }
        } catch (e: Exception) {
            null
        } finally {
            retriever.release()
        }
    }

    private fun createVideoFromFrames(framePaths: List<String>?, outputPath: String?, fps: Int): Boolean {
        if (framePaths == null || outputPath == null || framePaths.isEmpty()) return false

        return try {
            // 注意: Android的MediaCodec创建视频比较复杂
            // 这里提供一个简化实现，实际应用中建议使用FFmpeg
            // 由于没有FFmpeg，这里简单返回false，让上层知道需要其他方案
            
            // 实际实现需要：
            // 1. 使用MediaCodec和MediaMuxer
            // 2. 将所有帧图片编码为H.264视频
            // 3. 设置正确的时间戳和帧率
            
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun createMotionPhoto(imagePath: String?, videoPath: String?, outputPath: String?): Boolean {
        if (imagePath == null || videoPath == null || outputPath == null) return false

        return try {
            // Motion Photo格式：JPEG图片 + XMP元数据 + MP4视频
            // 这是一个简化实现，实际需要添加正确的XMP元数据
            
            val imageFile = File(imagePath)
            val videoFile = File(videoPath)
            val outputFile = File(outputPath)

            FileOutputStream(outputFile).use { output ->
                // 写入JPEG图片
                FileInputStream(imageFile).use { input ->
                    input.copyTo(output)
                }

                // 写入视频数据
                FileInputStream(videoFile).use { input ->
                    input.copyTo(output)
                }
            }

            true
        } catch (e: Exception) {
            false
        }
    }

    private fun saveToGallery(filePath: String?): Boolean {
        if (filePath == null) return false

        val file = File(filePath)
        if (!file.exists()) return false

        return try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, file.name)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }

            val resolver: ContentResolver = contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)

            if (uri != null) {
                resolver.openOutputStream(uri)?.use { output ->
                    FileInputStream(file).use { input ->
                        input.copyTo(output)
                    }
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}
