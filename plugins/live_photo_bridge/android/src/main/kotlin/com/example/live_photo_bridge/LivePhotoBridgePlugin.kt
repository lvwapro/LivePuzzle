package com.example.live_photo_bridge

import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.MediaStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class LivePhotoBridgePlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "live_photo_bridge")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getLivePhotoIds" -> {
                getLivePhotoIds(result)
            }
            "getVideoPath" -> {
                val assetId = call.argument<String>("assetId")
                if (assetId != null) {
                    getVideoPath(assetId, result)
                } else {
                    result.error("INVALID_ARGS", "Asset ID is required", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getLivePhotoIds(result: Result) {
        val ids = mutableListOf<String>()
        
        // Android 原生识别动态照片
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.SIZE
        )
        
        // 多重检测策略
        val selection = buildString {
            append("${MediaStore.Images.Media.MIME_TYPE} LIKE 'image/%'")
            append(" AND (")
            // 1. 检查 Android 11+ 的标准 Motion Photo 字段
            append("${MediaStore.Images.Media.IS_PENDING}=0")
            // 2. 文件名特征检测 (小米 MVIMG, vivo MPIMG 等)
            append(" OR ${MediaStore.Images.Media.DISPLAY_NAME} LIKE 'MVIMG%'")
            append(" OR ${MediaStore.Images.Media.DISPLAY_NAME} LIKE 'MPIMG%'")
            append(" OR ${MediaStore.Images.Media.DISPLAY_NAME} LIKE '%_MOTION%'")
            append(")")
        }
        
        try {
            val cursor: Cursor? = context.contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                null,
                "${MediaStore.Images.Media.DATE_ADDED} DESC"
            )
            
            cursor?.use {
                val idColumn = it.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                val nameColumn = it.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
                val sizeColumn = it.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)
                
                while (it.moveToNext()) {
                    val id = it.getString(idColumn)
                    val name = it.getString(nameColumn)
                    val size = it.getLong(sizeColumn)
                    
                    // 补充检查：Motion Photo 通常 > 4MB (因为内嵌视频)
                    if (name.startsWith("MVIMG") || 
                        name.startsWith("MPIMG") || 
                        name.contains("MOTION") ||
                        size > 4 * 1024 * 1024) {
                        ids.add(id)
                    }
                }
            }
            
            println("✅ Android原生: 找到 ${ids.size} 张动态照片")
            result.success(ids)
        } catch (e: Exception) {
            println("❌ Android原生: 查询失败 ${e.message}")
            result.error("QUERY_FAILED", e.message, null)
        }
    }

    private fun getVideoPath(assetId: String, result: Result) {
        val projection = arrayOf(MediaStore.Images.Media.DATA)
        val selection = "${MediaStore.Images.Media._ID}=?"
        val selectionArgs = arrayOf(assetId)

        try {
            val cursor = context.contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null
            )
            
            cursor?.use {
                if (it.moveToFirst()) {
                    val path = it.getString(it.getColumnIndexOrThrow(MediaStore.Images.Media.DATA))
                    println("✅ Android原生: 返回图片路径 $path (需 Flutter 端提取内嵌视频)")
                    result.success(path)
                } else {
                    result.error("NOT_FOUND", "Asset not found", null)
                }
            }
        } catch (e: Exception) {
            result.error("QUERY_FAILED", e.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
