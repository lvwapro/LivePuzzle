import Flutter
import UIKit
import Photos
import AVFoundation
import ImageIO

public class LivePhotoBridgePlugin: NSObject, FlutterPlugin {
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
    case "createLivePhotoHardware":
      if let args = call.arguments as? [String: Any],
         let assetIds = args["assetIds"] as? [String],
         let layoutConfig = args["layoutConfig"] as? [String: Any],
         let coverTimes = args["coverTimes"] as? [Int] {
        createLivePhotoHardware(assetIds: assetIds, layoutConfig: layoutConfig, coverTimes: coverTimes, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "assetIds, layoutConfig and coverTimes are required", details: nil))
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

  // MARK: - Software Live Photo Creation
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
  
  // MARK: - Pixel Buffer Utilities

  func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
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
