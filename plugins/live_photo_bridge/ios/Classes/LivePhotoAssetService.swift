import Flutter
import UIKit
import Photos
import AVFoundation

/// PHAsset 操作：获取 Live Photo ID 列表、提取视频路径、提取帧、获取时长
extension LivePhotoBridgePlugin {

  func getLivePhotoIds(result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let fetchOptions = PHFetchOptions()
      
      fetchOptions.predicate = NSPredicate(
        format: "mediaType == %d && (mediaSubtype & %d) != 0",
        PHAssetMediaType.image.rawValue,
        PHAssetMediaSubtype.photoLive.rawValue
      )
      
      fetchOptions.sortDescriptors = [
        NSSortDescriptor(key: "creationDate", ascending: false)
      ]
      
      let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
      var ids: [String] = []
      
      fetchResult.enumerateObjects { (asset, _, _) in
        if asset.mediaSubtypes.contains(.photoLive) {
          ids.append(asset.localIdentifier)
        }
      }
      
      DispatchQueue.main.async {
        print("✅ iOS原生: 找到 \(ids.count) 张实况照片")
        result(ids)
      }
    }
  }

  func getVideoPath(assetId: String, result: @escaping FlutterResult) {
    print("🎬 iOS原生: 开始获取视频 \(assetId)")
    
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    
    guard let asset = fetchResult.firstObject else {
      print("❌ iOS原生: 未找到资源")
      result(FlutterError(code: "NOT_FOUND", message: "Asset not found", details: nil))
      return
    }

    guard asset.mediaSubtypes.contains(.photoLive) else {
      print("❌ iOS原生: 不是实况照片")
      result(FlutterError(code: "NOT_LIVE_PHOTO", message: "Not a Live Photo", details: nil))
      return
    }

    let options = PHLivePhotoRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true
    
    print("📥 iOS原生: 请求 Live Photo 资源")
    
    PHImageManager.default().requestLivePhoto(
      for: asset,
      targetSize: PHImageManagerMaximumSize,
      contentMode: .default,
      options: options
    ) { livePhoto, info in
      if let livePhoto = livePhoto {
        print("✅ iOS原生: 获取到 Live Photo 对象")
        self.extractVideoFromLivePhoto(livePhoto: livePhoto, assetId: assetId, result: result)
      } else if let error = info?[PHImageErrorKey] as? NSError {
        print("❌ iOS原生: 请求失败 - \(error.localizedDescription)")
        result(FlutterError(code: "REQUEST_FAILED", message: error.localizedDescription, details: nil))
      } else {
        print("❌ iOS原生: 未获取到 Live Photo")
        result(FlutterError(code: "NO_LIVE_PHOTO", message: "Failed to get Live Photo", details: nil))
      }
    }
  }
  
  func extractVideoFromLivePhoto(livePhoto: PHLivePhoto, assetId: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
      guard let asset = fetchResult.firstObject else {
        DispatchQueue.main.async {
          result(FlutterError(code: "NOT_FOUND", message: "Asset not found", details: nil))
        }
        return
      }
      
      let resources = PHAssetResource.assetResources(for: asset)
      guard let videoResource = resources.first(where: { $0.type == .pairedVideo }) else {
        DispatchQueue.main.async {
          result(FlutterError(code: "NO_VIDEO", message: "No paired video found", details: nil))
        }
        return
      }
      
      let tempDir = NSTemporaryDirectory()
      let timestamp = Int(Date().timeIntervalSince1970)
      let fileName = "live_\(timestamp)_\(arc4random_uniform(10000)).mov"
      let videoURL = URL(fileURLWithPath: tempDir).appendingPathComponent(fileName)
      
      try? FileManager.default.removeItem(at: videoURL)
      
      let options = PHAssetResourceRequestOptions()
      options.isNetworkAccessAllowed = true
      
      var lastProgress: Double = 0
      options.progressHandler = { progress in
        if progress - lastProgress >= 0.1 {
          print("📥 iOS原生: 下载进度 \(Int(progress * 100))%")
          lastProgress = progress
        }
      }
      
      print("📥 iOS原生: 开始导出视频")
      
      PHAssetResourceManager.default().writeData(
        for: videoResource,
        toFile: videoURL,
        options: options
      ) { error in
        DispatchQueue.main.async {
          if let error = error {
            let nsError = error as NSError
            print("❌ iOS原生: 导出失败 - Code: \(nsError.code), Domain: \(nsError.domain)")
            
            var message = "视频导出失败"
            if nsError.domain == "PHPhotosErrorDomain" {
              switch nsError.code {
              case -1:
                message = "视频资源暂时不可用，可能正在从iCloud下载"
              case 3164:
                message = "需要网络连接来下载iCloud照片"
              default:
                message = "PHPhotos错误 \(nsError.code): \(nsError.localizedDescription)"
              }
            }
            
            result(FlutterError(
              code: "EXPORT_FAILED",
              message: message,
              details: "Domain: \(nsError.domain), Code: \(nsError.code)"
            ))
          } else {
            print("✅ iOS原生: 视频导出成功 \(videoURL.path)")
            result(videoURL.path)
          }
        }
      }
    }
  }
  
  func extractFrame(videoPath: String, timeMs: Int, result: @escaping FlutterResult) {
    print("🎬 iOS原生: 开始提取帧 - 视频路径: \(videoPath), 时间: \(timeMs)ms")
    
    DispatchQueue.global(qos: .userInitiated).async {
      let videoURL = URL(fileURLWithPath: videoPath)
      let asset = AVURLAsset(url: videoURL)
      let imageGenerator = AVAssetImageGenerator(asset: asset)
      imageGenerator.appliesPreferredTrackTransform = true
      imageGenerator.requestedTimeToleranceBefore = .zero
      imageGenerator.requestedTimeToleranceAfter = .zero
      
      let time = CMTime(value: Int64(timeMs), timescale: 1000)
      
      do {
        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        let uiImage = UIImage(cgImage: cgImage)
        
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.95) else {
          DispatchQueue.main.async {
            result(FlutterError(code: "ENCODE_FAILED", message: "Failed to encode image", details: nil))
          }
          return
        }
        
        let tempDir = NSTemporaryDirectory()
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "frame_\(timestamp)_\(arc4random_uniform(10000)).jpg"
        let framePath = URL(fileURLWithPath: tempDir).appendingPathComponent(fileName)
        
        try jpegData.write(to: framePath)
        
        DispatchQueue.main.async {
          print("✅ iOS原生: 帧提取成功 [\(cgImage.width)x\(cgImage.height)] - \(framePath.path)")
          result(framePath.path)
        }
      } catch {
        DispatchQueue.main.async {
          print("❌ iOS原生: 帧提取失败 - \(error.localizedDescription)")
          result(FlutterError(code: "EXTRACTION_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
  
  func getVideoDuration(assetId: String, result: @escaping FlutterResult) {
    print("⏱️ iOS原生: 获取视频时长 - \(assetId)")
    
    DispatchQueue.global(qos: .userInitiated).async {
      let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
      
      guard let asset = fetchResult.firstObject else {
        DispatchQueue.main.async {
          result(FlutterError(code: "NOT_FOUND", message: "Asset not found", details: nil))
        }
        return
      }
      
      guard asset.mediaSubtypes.contains(.photoLive) else {
        DispatchQueue.main.async { result(0) }
        return
      }
      
      let resources = PHAssetResource.assetResources(for: asset)
      guard let videoResource = resources.first(where: { $0.type == .pairedVideo }) else {
        DispatchQueue.main.async { result(0) }
        return
      }
      
      let tempDir = NSTemporaryDirectory()
      let timestamp = Int(Date().timeIntervalSince1970)
      let fileName = "duration_check_\(timestamp).mov"
      let videoURL = URL(fileURLWithPath: tempDir).appendingPathComponent(fileName)
      
      try? FileManager.default.removeItem(at: videoURL)
      
      let options = PHAssetResourceRequestOptions()
      options.isNetworkAccessAllowed = true
      
      PHAssetResourceManager.default().writeData(
        for: videoResource,
        toFile: videoURL,
        options: options
      ) { error in
        if let error = error {
          DispatchQueue.main.async {
            print("❌ iOS原生: 获取视频失败 - \(error.localizedDescription)")
            result(0)
          }
          return
        }
        
        let avAsset = AVURLAsset(url: videoURL)
        let duration = avAsset.duration
        let durationMs = Int(CMTimeGetSeconds(duration) * 1000)
        
        print("✅ iOS原生: 视频时长 - \(durationMs)ms")
        
        try? FileManager.default.removeItem(at: videoURL)
        
        DispatchQueue.main.async { result(durationMs) }
      }
    }
  }
}
