import Flutter
import UIKit
import Photos
import AVFoundation
import ImageIO

public class LivePhotoBridgePlugin: NSObject, FlutterPlugin {
  private let imageManager = PHCachingImageManager()
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "live_photo_bridge", binaryMessenger: registrar.messenger())
    let instance = LivePhotoBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getLivePhotoIds":
      getLivePhotoIds(result: result)
    case "getVideoPath":
      if let args = call.arguments as? [String: Any], 
         let assetId = args["assetId"] as? String {
        getVideoPath(assetId: assetId, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "Asset ID is required", details: nil))
      }
    case "extractFrame":
      if let args = call.arguments as? [String: Any],
         let videoPath = args["videoPath"] as? String,
         let timeMs = args["timeMs"] as? Int {
        extractFrame(videoPath: videoPath, timeMs: timeMs, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "videoPath and timeMs are required", details: nil))
      }
    case "createLivePhoto":
      if let args = call.arguments as? [String: Any],
         let frameImagePaths = args["frameImagePaths"] as? [String],
         let coverFrameIndex = args["coverFrameIndex"] as? Int {
        createLivePhoto(frameImagePaths: frameImagePaths, coverFrameIndex: coverFrameIndex, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "frameImagePaths and coverFrameIndex are required", details: nil))
      }
    case "getVideoDuration":
      if let args = call.arguments as? [String: Any],
         let assetId = args["assetId"] as? String {
        getVideoDuration(assetId: assetId, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "assetId is required", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // 获取所有实况照片 ID
  private func getLivePhotoIds(result: @escaping FlutterResult) {
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

  // 获取实况照片的视频部分
  private func getVideoPath(assetId: String, result: @escaping FlutterResult) {
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
        result(FlutterError(
          code: "REQUEST_FAILED",
          message: error.localizedDescription,
          details: nil
        ))
      } else {
        print("❌ iOS原生: 未获取到 Live Photo")
        result(FlutterError(
          code: "NO_LIVE_PHOTO",
          message: "Failed to get Live Photo",
          details: nil
        ))
      }
    }
  }
  
  // 从 PHLivePhoto 提取视频
  private func extractVideoFromLivePhoto(livePhoto: PHLivePhoto, assetId: String, result: @escaping FlutterResult) {
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
  
  // 从视频中提取指定时间点的帧（使用原始分辨率，不缩放）
  private func extractFrame(videoPath: String, timeMs: Int, result: @escaping FlutterResult) {
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
        // 使用原始分辨率，不缩放
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
  
  // 🔥 获取 Live Photo 视频的实际时长（毫秒）
  private func getVideoDuration(assetId: String, result: @escaping FlutterResult) {
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
        DispatchQueue.main.async {
          result(0)
        }
        return
      }
      
      let resources = PHAssetResource.assetResources(for: asset)
      guard let videoResource = resources.first(where: { $0.type == .pairedVideo }) else {
        DispatchQueue.main.async {
          result(0)
        }
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
        
        DispatchQueue.main.async {
          result(durationMs)
        }
      }
    }
  }
  
  // 调整图片大小（仅在 createLivePhoto 封面压缩时使用）
  private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
    let size = image.size
    let widthRatio  = targetSize.width  / size.width
    let heightRatio = targetSize.height / size.height
    let ratio = min(widthRatio, heightRatio)
    let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
    
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return newImage ?? image
  }
  
  // 🔥 创建 Live Photo 并保存到图库
  private func createLivePhoto(frameImagePaths: [String], coverFrameIndex: Int, result: @escaping FlutterResult) {
    print("🎬 iOS原生: 开始创建 Live Photo - 总帧数: \(frameImagePaths.count), 封面帧: \(coverFrameIndex)")
    
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let tempDir = NSTemporaryDirectory()
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // 生成唯一标识符用于 Live Photo 配对
        let assetIdentifier = UUID().uuidString
        print("🆔 iOS原生: Live Photo 标识符 - \(assetIdentifier)")
        
        // fps 与 createVideoFromFrames 保持一致
        let fps: Int32 = 15
        let safeIndex = min(coverFrameIndex, frameImagePaths.count - 1)
        
        // 1. 准备封面图片
        let coverImagePath = frameImagePaths[safeIndex]
        guard let coverImage = UIImage(contentsOfFile: coverImagePath) else {
          throw NSError(domain: "LivePhotoBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load cover image"])
        }
        
        let coverURL = URL(fileURLWithPath: tempDir).appendingPathComponent("live_puzzle_cover_\(timestamp).jpg")
        
        guard let imageData = coverImage.jpegData(compressionQuality: 0.95) else {
          throw NSError(domain: "LivePhotoBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode cover image"])
        }
        
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageType = CGImageSourceGetType(source) else {
          throw NSError(domain: "LivePhotoBridge", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create image source"])
        }
        
        guard let destination = CGImageDestinationCreateWithURL(coverURL as CFURL, imageType, 1, nil) else {
          throw NSError(domain: "LivePhotoBridge", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
          throw NSError(domain: "LivePhotoBridge", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to read image properties"])
        }
        
        var mutableProperties = imageProperties
        
        // 用实际 coverFrameIndex 计算 still image time（秒）
        let coverTimeSeconds = Double(safeIndex) / Double(fps)
        
        let makerApple: [String: Any] = [
          "17": assetIdentifier,                                       // Content Identifier - Live Photo 配对标识符
          "8": String(format: "%.6f", coverTimeSeconds)                // Still Image Time（秒，字符串格式）
        ]
        
        mutableProperties[kCGImagePropertyMakerAppleDictionary as String] = makerApple
        
        if let orientation = imageProperties[kCGImagePropertyOrientation as String] {
          mutableProperties[kCGImagePropertyOrientation as String] = orientation
        }
        
        print("📝 iOS原生: 封面元数据 - Identifier: \(assetIdentifier), StillTime: \(String(format: "%.6f", coverTimeSeconds))s")
        
        CGImageDestinationAddImageFromSource(destination, source, 0, mutableProperties as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
          throw NSError(domain: "LivePhotoBridge", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to write image with metadata"])
        }
        
        print("✅ iOS原生: 封面图片准备完成（带元数据）")
        
        // 2. 创建视频（带有 Live Photo 元数据 + timed metadata track）
        print("📹 iOS原生: 开始创建视频...")
        let videoURL = URL(fileURLWithPath: tempDir).appendingPathComponent("live_puzzle_\(timestamp).mov")
        try self.createVideoFromFrames(
          framePaths: frameImagePaths,
          outputURL: videoURL,
          assetIdentifier: assetIdentifier,
          coverFrameIndex: safeIndex
        )
        print("✅ iOS原生: 视频创建成功 - \(videoURL.path)")
        
        // 3. 验证文件存在
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
          throw NSError(domain: "LivePhotoBridge", code: -6, userInfo: [NSLocalizedDescriptionKey: "Video file not found"])
        }
        guard FileManager.default.fileExists(atPath: coverURL.path) else {
          throw NSError(domain: "LivePhotoBridge", code: -7, userInfo: [NSLocalizedDescriptionKey: "Cover file not found"])
        }
        
        // 4. 检查相册权限
        let authStatus = PHPhotoLibrary.authorizationStatus()
        if authStatus != .authorized {
          print("⚠️ iOS原生: 请求相册权限...")
          let semaphore = DispatchSemaphore(value: 0)
          var granted = false
          
          PHPhotoLibrary.requestAuthorization { status in
            granted = (status == .authorized)
            semaphore.signal()
          }
          
          semaphore.wait()
          
          if !granted {
            throw NSError(domain: "LivePhotoBridge", code: -8, userInfo: [NSLocalizedDescriptionKey: "Photo library permission denied"])
          }
        }
        
        print("📸 iOS原生: 开始保存到图库...")
        
        // 5. 创建 Live Photo 并保存到图库
        var saveError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        
        PHPhotoLibrary.shared().performChanges({
          let request = PHAssetCreationRequest.forAsset()
          request.addResource(with: .photo, fileURL: coverURL, options: nil)
          
          let videoOptions = PHAssetResourceCreationOptions()
          videoOptions.shouldMoveFile = false
          request.addResource(with: .pairedVideo, fileURL: videoURL, options: videoOptions)
          
          print("✅ iOS原生: 资源已添加到创建请求")
          
        }) { success, error in
          if let error = error {
            let nsError = error as NSError
            print("❌ iOS原生: 保存失败 - Code: \(nsError.code), \(nsError.localizedDescription)")
            saveError = error
          } else if success {
            print("✅ iOS原生: Live Photo 保存成功")
          }
          semaphore.signal()
        }
        
        semaphore.wait()
        
        try? FileManager.default.removeItem(at: videoURL)
        try? FileManager.default.removeItem(at: coverURL)
        
        DispatchQueue.main.async {
          if let error = saveError {
            result(FlutterError(
              code: "SAVE_FAILED",
              message: error.localizedDescription,
              details: nil
            ))
          } else {
            result(true)
          }
        }
        
      } catch {
        DispatchQueue.main.async {
          print("❌ iOS原生: 创建 Live Photo 失败 - \(error.localizedDescription)")
          result(FlutterError(code: "CREATE_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
  
  // 🔥 从图片帧创建视频（包含 timed metadata track 以支持 still-image-time）
  private func createVideoFromFrames(
    framePaths: [String],
    outputURL: URL,
    assetIdentifier: String,
    coverFrameIndex: Int
  ) throws {
    guard !framePaths.isEmpty else {
      throw NSError(domain: "LivePhotoBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "No frames provided"])
    }
    
    guard let firstImage = UIImage(contentsOfFile: framePaths[0]) else {
      throw NSError(domain: "LivePhotoBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to load first frame"])
    }
    
    let videoSize = firstImage.size
    print("📐 iOS原生: 视频尺寸 - \(videoSize.width) x \(videoSize.height)")
    
    // Live Photo 视频规范：30 帧 / 15fps = 2 秒
    let fps: Int32 = 15
    let frameDuration = CMTime(value: 1, timescale: fps)
    
    try? FileManager.default.removeItem(at: outputURL)
    
    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
    
    // ── 容器级元数据：仅保留 content.identifier ──
    let contentIdItem = AVMutableMetadataItem()
    contentIdItem.key = "com.apple.quicktime.content.identifier" as NSString
    contentIdItem.keySpace = AVMetadataKeySpace.quickTimeMetadata
    contentIdItem.value = assetIdentifier as NSString
    contentIdItem.dataType = "com.apple.metadata.datatype.UTF-8"
    writer.metadata = [contentIdItem]
    
    // ── 视频轨道（提升码率到 10 Mbps，High profile，BGRA 像素格式）──
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: Int(videoSize.width),
      AVVideoHeightKey: Int(videoSize.height),
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 10_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
      ]
    ]
    
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    writerInput.expectsMediaDataInRealTime = false
    
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: writerInput,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: Int(videoSize.width),
        kCVPixelBufferHeightKey as String: Int(videoSize.height)
      ]
    )
    
    guard writer.canAdd(writerInput) else {
      throw NSError(domain: "LivePhotoBridge", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot add video writer input"])
    }
    writer.add(writerInput)
    
    // ── Timed metadata track（still-image-time，iOS Photos 要求）──
    let metaSpec: [String: Any] = [
      kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String:
        "mdta/com.apple.quicktime.still-image-time",
      kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String:
        "com.apple.metadata.datatype.int8"
    ]
    var metaFormatDesc: CMFormatDescription?
    CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
      allocator: kCFAllocatorDefault,
      metadataType: kCMMetadataFormatType_Boxed,
      metadataSpecifications: [metaSpec] as CFArray,
      formatDescriptionOut: &metaFormatDesc
    )
    
    let metaInput = AVAssetWriterInput(
      mediaType: .metadata,
      outputSettings: nil,
      sourceFormatHint: metaFormatDesc
    )
    metaInput.expectsMediaDataInRealTime = false
    let metaAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metaInput)
    
    guard writer.canAdd(metaInput) else {
      throw NSError(domain: "LivePhotoBridge", code: -3, userInfo: [NSLocalizedDescriptionKey: "Cannot add metadata writer input"])
    }
    writer.add(metaInput)
    
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    
    // ── 在 coverFrameIndex 对应时间点写入 still-image-time ──
    let coverTime = CMTimeMultiply(frameDuration, multiplier: Int32(coverFrameIndex))
    let coverRange = CMTimeRange(start: coverTime, duration: frameDuration)
    let stillItem = AVMutableMetadataItem()
    stillItem.key = "com.apple.quicktime.still-image-time" as NSString
    stillItem.keySpace = AVMetadataKeySpace.quickTimeMetadata
    stillItem.value = NSNumber(value: 0)  // 值本身无意义，时间由 presentationTime 决定
    stillItem.dataType = "com.apple.metadata.datatype.int8"
    let metaGroup = AVTimedMetadataGroup(items: [stillItem], timeRange: coverRange)
    metaAdaptor.append(metaGroup)
    metaInput.markAsFinished()
    
    print("📹 iOS原生: 开始写入 \(framePaths.count) 帧，封面帧: \(coverFrameIndex)...")
    
    var frameCount: Int64 = 0
    
    for (index, framePath) in framePaths.enumerated() {
      autoreleasepool {
        guard let image = UIImage(contentsOfFile: framePath) else {
          print("⚠️ iOS原生: 跳过帧 \(index) - 无法加载")
          return
        }
        
        guard let pixelBuffer = self.pixelBuffer(from: image, size: videoSize) else {
          print("⚠️ iOS原生: 跳过帧 \(index) - 无法创建 PixelBuffer")
          return
        }
        
        while !writerInput.isReadyForMoreMediaData {
          Thread.sleep(forTimeInterval: 0.01)
        }
        
        let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
        
        if adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
          frameCount += 1
          if index % 10 == 0 {
            print("📹 iOS原生: 已写入 \(frameCount) 帧")
          }
        } else {
          print("⚠️ iOS原生: 添加帧 \(index) 失败")
        }
      }
    }
    
    print("📹 iOS原生: 完成写入 \(frameCount) 帧，正在结束...")
    
    writerInput.markAsFinished()
    
    let semaphore = DispatchSemaphore(value: 0)
    var finishError: Error?
    
    writer.finishWriting {
      finishError = writer.error
      semaphore.signal()
    }
    
    semaphore.wait()
    
    if let error = finishError {
      throw error
    }
    
    if writer.status != .completed {
      throw NSError(domain: "LivePhotoBridge", code: -4, userInfo: [NSLocalizedDescriptionKey: "Video writing did not complete, status: \(writer.status.rawValue)"])
    }
    
    let fileSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? UInt64 ?? 0
    print("✅ iOS原生: 视频创建成功 - 大小: \(fileSize) bytes, 帧数: \(frameCount)")
    
    if fileSize == 0 {
      throw NSError(domain: "LivePhotoBridge", code: -5, userInfo: [NSLocalizedDescriptionKey: "Video file is empty"])
    }
  }
  
  // 🔥 将 UIImage 转换为 CVPixelBuffer（使用 BGRA 格式，与 CG drawing 匹配）
  private func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
    let attrs = [
      kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
      kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
    ] as CFDictionary
    
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      Int(size.width),
      Int(size.height),
      kCVPixelFormatType_32BGRA,
      attrs,
      &pixelBuffer
    )
    
    guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
      return nil
    }
    
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    
    let context = CGContext(
      data: CVPixelBufferGetBaseAddress(buffer),
      width: Int(size.width),
      height: Int(size.height),
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    )
    
    guard let cgContext = context, let cgImage = image.cgImage else {
      return nil
    }
    
    cgContext.draw(cgImage, in: CGRect(origin: .zero, size: size))
    
    return buffer
  }
}
