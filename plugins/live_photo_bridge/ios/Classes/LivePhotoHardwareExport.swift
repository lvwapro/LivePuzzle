import Flutter
import UIKit
import Photos
import AVFoundation
import ImageIO

/// 硬件加速 Live Photo 合成、封面提取与相册保存
extension LivePhotoBridgePlugin {

  func createLivePhotoHardware(
    assetIds: [String],
    layoutConfig: [String: Any],
    coverTimes: [Int],
    result: @escaping FlutterResult
  ) {
    print("🚀 开始硬件加速合成(v4): \(assetIds.count)路视频")

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        guard let canvasWidth = layoutConfig["canvasWidth"] as? Double,
              let canvasHeight = layoutConfig["canvasHeight"] as? Double,
              let blocksData = layoutConfig["blocks"] as? [[String: Any]] else {
          throw NSError(domain: "LivePhotoBridge", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid layout config"])
        }

        let blocks = try blocksData.map { blockData -> HardwareVideoCompositor.LayoutBlock in
          guard let x = blockData["x"] as? Double,
                let y = blockData["y"] as? Double,
                let width = blockData["width"] as? Double,
                let height = blockData["height"] as? Double else {
            throw NSError(domain: "LivePhotoBridge", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid block data"])
          }
          return HardwareVideoCompositor.LayoutBlock(
            x: x, y: y, width: width, height: height,
            scale: blockData["scale"] as? Double ?? 1.0,
            offsetX: blockData["offsetX"] as? Double ?? 0.0,
            offsetY: blockData["offsetY"] as? Double ?? 0.0
          )
        }

        let isLongImage = layoutConfig["isLongImage"] as? Bool ?? false
        let config = HardwareVideoCompositor.CompositorConfig(
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
          blocks: blocks,
          coverTimes: coverTimes,
          isLongImage: isLongImage
        )

        let allStatic = assetIds.allSatisfy { !self.assetHasPairedVideo(assetId: $0) }
        if allStatic {
          print("📷 全部为静态图，仅导出合成静态照片")
          guard let compositeImage = self.compositeHighResStill(assetIds: assetIds, videoAssets: [], config: config) else {
            throw NSError(domain: "LivePhotoBridge", code: -8,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to composite still image"])
          }
          let imageURL = FileManager.default.temporaryDirectory.appendingPathComponent("static_export_\(UUID().uuidString).jpg")
          try self.writeImageToFile(compositeImage, to: imageURL)
          try self.saveStaticPhotoToLibrary(imageURL: imageURL)
          try? FileManager.default.removeItem(at: imageURL)
          DispatchQueue.main.async {
            print("✅ 静态图导出完成！")
            result(true)
          }
          return
        }

        print("📥 获取 \(assetIds.count) 个视频资源...")
        let videoAssets = try self.fetchVideoAssetsSync(assetIds: assetIds)

        let compositor = try HardwareVideoCompositor(videoAssets: videoAssets, config: config)

        let assetIdentifier = UUID().uuidString
        print("🆔 Live Photo 标识符: \(assetIdentifier)")

        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("lp_final_\(UUID().uuidString).mov")
        print("⚡ 开始硬件合成...")
        try compositor.compose(outputURL: videoURL, assetIdentifier: assetIdentifier)

        print("📸 合成高分辨率封面图片... coverTimes=\(coverTimes)")
        let coverTimeMs = coverTimes.first ?? 0
        let coverImage: UIImage
        if let hiResCover = self.compositeHighResStill(assetIds: assetIds, videoAssets: videoAssets, config: config) {
          coverImage = hiResCover
        } else {
          print("⚠️ 高清封面合成失败，降级到视频帧提取")
          coverImage = try self.extractCoverImage(from: videoURL, atTimeMs: coverTimeMs)
        }
        let coverImageURL = tempDir.appendingPathComponent("lp_cover_\(UUID().uuidString).jpg")
        try self.writeCoverImage(coverImage, to: coverImageURL, assetIdentifier: assetIdentifier, coverTimeMs: coverTimeMs)

        print("💾 保存到相册...")
        try self.saveLivePhotoToLibrary(videoURL: videoURL, imageURL: coverImageURL)

        try? FileManager.default.removeItem(at: videoURL)
        try? FileManager.default.removeItem(at: coverImageURL)

        DispatchQueue.main.async {
          print("✅ 硬件加速合成完成！")
          result(true)
        }

      } catch {
        DispatchQueue.main.async {
          print("❌ 硬件合成失败: \(error.localizedDescription)")
          result(FlutterError(
            code: "HARDWARE_COMPOSITION_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  // MARK: - Video Asset Fetching

  func assetHasPairedVideo(assetId: String) -> Bool {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetchResult.firstObject else { return false }
    let resources = PHAssetResource.assetResources(for: asset)
    return resources.contains(where: { $0.type == .pairedVideo })
  }

  func fetchVideoAssetsSync(assetIds: [String]) throws -> [AVAsset] {
    var videoAssets: [AVAsset] = []

    for assetId in assetIds {
      let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
      guard let asset = fetchResult.firstObject else {
        throw NSError(domain: "LivePhotoBridge", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Asset \(assetId) not found"])
      }

      let resources = PHAssetResource.assetResources(for: asset)
      let videoResource = resources.first(where: { $0.type == .pairedVideo })

      if let videoResource = videoResource {
        let tempURL = FileManager.default.temporaryDirectory
          .appendingPathComponent("src_video_\(UUID().uuidString).mov")

        let semaphore = DispatchSemaphore(value: 0)
        var fetchError: Error?

        PHAssetResourceManager.default().writeData(
          for: videoResource, toFile: tempURL, options: nil
        ) { error in
          fetchError = error
          semaphore.signal()
        }

        let timeout = DispatchTime.now() + .seconds(30)
        let waitResult = semaphore.wait(timeout: timeout)

        if waitResult == .timedOut {
          throw NSError(domain: "LivePhotoBridge", code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Timeout loading video for \(assetId)"])
        }
        if let error = fetchError { throw error }

        guard FileManager.default.fileExists(atPath: tempURL.path) else {
          throw NSError(domain: "LivePhotoBridge", code: -4,
                        userInfo: [NSLocalizedDescriptionKey: "Video file not created for \(assetId)"])
        }

        let avAsset = AVURLAsset(url: tempURL)
        let tracks = avAsset.tracks(withMediaType: .video)
        guard !tracks.isEmpty else {
          throw NSError(domain: "LivePhotoBridge", code: -5,
                        userInfo: [NSLocalizedDescriptionKey: "No video track in \(assetId)"])
        }

        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        let testTime = CMTime(value: 0, timescale: 1)
        do {
          _ = try generator.copyCGImage(at: testTime, actualTime: nil)
          print("✅ 视频资源可解码验证通过: \(assetId.prefix(8))…")
        } catch {
          throw NSError(domain: "LivePhotoBridge", code: -6,
                        userInfo: [NSLocalizedDescriptionKey: "Video not decodable: \(error)"])
        }
        print("📥 视频资源已导出并验证: \(assetId.prefix(8))… (\(tracks.count) tracks)")
        videoAssets.append(avAsset)
      } else {
        guard let image = fetchStillImage(assetId: assetId) else {
          throw NSError(domain: "LivePhotoBridge", code: -7,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot load image for non-Live asset \(assetId)"])
        }
        let tempURL = FileManager.default.temporaryDirectory
          .appendingPathComponent("static_video_\(UUID().uuidString).mov")
        let avAsset = try createStaticVideoFromImage(image: image, outputURL: tempURL, durationSeconds: 3)
        print("📥 非实况图片已生成为静态视频: \(assetId.prefix(8))…")
        videoAssets.append(avAsset)
      }
    }

    return videoAssets
  }

  // MARK: - Static Video Generation

  func createStaticVideoFromImage(image: UIImage, outputURL: URL, durationSeconds: Int = 3) throws -> AVAsset {
    let videoSize = image.size
    let fps: Int32 = 30
    let frameCount = Int64(durationSeconds) * Int64(fps)
    let frameDuration = CMTime(value: 1, timescale: fps)

    try? FileManager.default.removeItem(at: outputURL)

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: Int(videoSize.width),
      AVVideoHeightKey: Int(videoSize.height),
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 6_000_000,
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
      throw NSError(domain: "LivePhotoBridge", code: -10,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot add video writer input for static image"])
    }
    writer.add(writerInput)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    guard let pixelBuf = pixelBuffer(from: image, size: videoSize) else {
      throw NSError(domain: "LivePhotoBridge", code: -11,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer from image"])
    }

    for i in 0..<frameCount {
      while !writerInput.isReadyForMoreMediaData {
        Thread.sleep(forTimeInterval: 0.01)
      }
      let presentationTime = CMTime(value: i, timescale: fps)
      _ = adaptor.append(pixelBuf, withPresentationTime: presentationTime)
    }
    writerInput.markAsFinished()

    let semaphore = DispatchSemaphore(value: 0)
    var finishError: Error?
    writer.finishWriting {
      finishError = writer.error
      semaphore.signal()
    }
    semaphore.wait()
    if let error = finishError { throw error }
    if writer.status != .completed {
      throw NSError(domain: "LivePhotoBridge", code: -12,
                    userInfo: [NSLocalizedDescriptionKey: "Static video write failed: \(writer.status.rawValue)"])
    }
    print("✅ 静态图已生成为 \(durationSeconds)s 视频: \(Int(videoSize.width))×\(Int(videoSize.height))")
    return AVURLAsset(url: outputURL)
  }

  // MARK: - Cover Image Compositing

  func compositeHighResStill(
    assetIds: [String],
    videoAssets: [AVAsset],
    config: HardwareVideoCompositor.CompositorConfig
  ) -> UIImage? {
    let canvasW = CGFloat(config.canvasWidth)
    let canvasH = CGFloat(config.canvasHeight)
    let coverW: CGFloat
    let coverH: CGFloat

    if config.isLongImage {
      let shortSide = min(canvasW, canvasH)
      let longSide  = max(canvasW, canvasH)
      let scale = min(min(1.0, 1080.0 / shortSide), 4096.0 / longSide)
      coverW = (canvasW * scale / 2).rounded() * 2
      coverH = (canvasH * scale / 2).rounded() * 2
    } else {
      let maxSide: CGFloat = 3024
      let aspect = canvasW / canvasH
      if aspect >= 1.0 {
        coverW = maxSide
        coverH = (maxSide / aspect).rounded()
      } else {
        coverW = (maxSide * aspect).rounded()
        coverH = maxSide
      }
    }
    let coverSize = CGSize(width: coverW, height: coverH)
    print("📸 封面尺寸: \(Int(coverW))×\(Int(coverH)), isLongImage=\(config.isLongImage)")

    var sourceImages: [UIImage] = []
    for (i, assetId) in assetIds.enumerated() {
      let coverTimeMs = i < config.coverTimes.count ? config.coverTimes[i] : 0

      if coverTimeMs > 0, i < videoAssets.count {
        let generator = AVAssetImageGenerator(asset: videoAssets[i])
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(value: 50, timescale: 1000)
        generator.requestedTimeToleranceAfter = CMTime(value: 50, timescale: 1000)
        let time = CMTime(value: Int64(coverTimeMs), timescale: 1000)
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
          sourceImages.append(UIImage(cgImage: cgImage))
          print("📸 封面[\(i)]: 使用自定义帧 @ \(coverTimeMs)ms")
        } else {
          print("⚠️ 封面[\(i)]: 提取自定义帧失败，降级到原图")
          guard let fallback = fetchStillImage(assetId: assetId) else { return nil }
          sourceImages.append(fallback)
        }
      } else {
        guard let img = fetchStillImage(assetId: assetId) else { return nil }
        sourceImages.append(img)
        print("📸 封面[\(i)]: 使用原始静态图")
      }
    }

    guard sourceImages.count == assetIds.count else { return nil }

    UIGraphicsBeginImageContextWithOptions(coverSize, true, 1.0)
    defer { UIGraphicsEndImageContext() }
    guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

    UIColor.black.setFill()
    UIRectFill(CGRect(origin: .zero, size: coverSize))

    for (i, image) in sourceImages.enumerated() {
      guard i < config.blocks.count else { break }
      let block = config.blocks[i]

      let dstX = block.x * coverW
      let dstY = block.y * coverH
      let dstW = block.width * coverW
      let dstH = block.height * coverH
      let dstRect = CGRect(x: dstX, y: dstY, width: dstW, height: dstH)

      let imgW = image.size.width
      let imgH = image.size.height
      guard imgW > 0, imgH > 0 else { continue }
      // BoxFit.cover：略放大缩放比(1.002)，避免浮点误差导致 scaled 略小于 dst 而出现左侧/上侧黑边
      let userScale = max(CGFloat(block.scale), 0.1)
      let scale = max(dstW / imgW, dstH / imgH) * 1.002 * userScale
      let scaledW = imgW * scale
      let scaledH = imgH * scale
      let panX = CGFloat(block.offsetX) / canvasW * coverW
      let panY = CGFloat(block.offsetY) / canvasH * coverH
      let drawX = dstX + (dstW - scaledW) / 2.0 + panX
      let drawY = dstY + (dstH - scaledH) / 2.0 + panY

      ctx.saveGState()
      ctx.clip(to: dstRect)
      image.draw(in: CGRect(x: drawX, y: drawY, width: scaledW, height: scaledH))
      ctx.restoreGState()
    }

    let composedImage = UIGraphicsGetImageFromCurrentImageContext()
    print("📸 高分辨率封面合成: \(Int(coverW))×\(Int(coverH)), 源图 \(sourceImages.count) 张")
    return composedImage
  }

  func fetchStillImage(assetId: String) -> UIImage? {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let phAsset = fetchResult.firstObject else { return nil }

    let options = PHImageRequestOptions()
    options.isSynchronous = true
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .exact
    options.isNetworkAccessAllowed = false

    var fetched: UIImage?
    PHImageManager.default().requestImage(
      for: phAsset,
      targetSize: CGSize(width: 4032, height: 4032),
      contentMode: .aspectFit,
      options: options
    ) { image, _ in
      fetched = image
    }
    return fetched
  }

  func extractCoverImage(from videoURL: URL, atTimeMs: Int) throws -> UIImage {
    let asset = AVAsset(url: videoURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 15)
    generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 15)

    let time = CMTime(value: CMTimeValue(atTimeMs), timescale: 1000)
    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
    return UIImage(cgImage: cgImage)
  }

  // MARK: - File I/O & Photo Library

  func writeImageToFile(_ image: UIImage, to url: URL) throws {
    guard let jpegData = image.jpegData(compressionQuality: 0.95) else {
      throw NSError(domain: "LivePhotoBridge", code: -13,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encode image as JPEG"])
    }
    try jpegData.write(to: url)
  }

  func writeCoverImage(
    _ image: UIImage,
    to url: URL,
    assetIdentifier: String,
    coverTimeMs: Int
  ) throws {
    guard let jpegData = image.jpegData(compressionQuality: 0.95),
          let source = CGImageSourceCreateWithData(jpegData as CFData, nil),
          let imageType = CGImageSourceGetType(source),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, imageType, 1, nil) else {
      throw NSError(domain: "LivePhotoBridge", code: -5,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create cover image destination"])
    }

    var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]) ?? [:]
    let coverTimeSec = Double(coverTimeMs) / 1000.0
    properties[kCGImagePropertyMakerAppleDictionary as String] = [
      "17": assetIdentifier,
      "8": String(format: "%.6f", coverTimeSec)
    ]

    CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw NSError(domain: "LivePhotoBridge", code: -6,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to write cover image"])
    }
  }

  func saveStaticPhotoToLibrary(imageURL: URL) throws {
    let semaphore = DispatchSemaphore(value: 0)
    var saveError: Error?
    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetCreationRequest.forAsset()
      request.addResource(with: .photo, fileURL: imageURL, options: nil)
    }) { success, error in
      saveError = success ? nil : (error ?? NSError(domain: "LivePhotoBridge", code: -1,
                                                     userInfo: [NSLocalizedDescriptionKey: "Save failed"]))
      semaphore.signal()
    }
    semaphore.wait()
    if let error = saveError { throw error }
  }

  func saveLivePhotoToLibrary(videoURL: URL, imageURL: URL) throws {
    let semaphore = DispatchSemaphore(value: 0)
    var saveError: Error?

    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetCreationRequest.forAsset()
      request.addResource(with: .photo, fileURL: imageURL, options: nil)
      let videoOptions = PHAssetResourceCreationOptions()
      videoOptions.shouldMoveFile = false
      request.addResource(with: .pairedVideo, fileURL: videoURL, options: videoOptions)
    }) { success, error in
      saveError = success ? nil : (error ?? NSError(domain: "LivePhotoBridge", code: -1,
                                                     userInfo: [NSLocalizedDescriptionKey: "Save failed"]))
      semaphore.signal()
    }

    semaphore.wait()
    if let error = saveError { throw error }
  }
}
