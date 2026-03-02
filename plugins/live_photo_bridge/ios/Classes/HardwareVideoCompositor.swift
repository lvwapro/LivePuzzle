import UIKit
import AVFoundation
import Photos
import CoreImage

/// 硬件加速视频合成器 v5
/// 使用 AVAssetReader(+videoComposition) + AVAssetWriter(H.264 硬编) 保证输出尺寸
/// 与 renderSize 严格一致，彻底解决黑边问题。
class HardwareVideoCompositor {

    // MARK: - Types

    struct LayoutBlock {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let scale: Double
        let offsetX: Double
        let offsetY: Double
    }

    struct CompositorConfig {
        let canvasWidth: Double
        let canvasHeight: Double
        let blocks: [LayoutBlock]
        let coverTimes: [Int]   // 毫秒
        let isLongImage: Bool   // 长图拼接模式（纵向/横向长图）
    }

    private struct SourceTrackInfo {
        let naturalSize: CGSize
        let preferredTransform: CGAffineTransform
    }

    // MARK: - Properties

    let config: CompositorConfig
    private let videoAssets: [AVAsset]
    let outputSize: CGSize
    private let targetDuration: CMTime = CMTime(value: 3, timescale: 1)

    // MARK: - Init

    init(videoAssets: [AVAsset], config: CompositorConfig) throws {
        self.videoAssets = videoAssets
        self.config = config

        let canvasW = CGFloat(config.canvasWidth)
        let canvasH = CGFloat(config.canvasHeight)

        let w: CGFloat
        let h: CGFloat

        if config.isLongImage {
            // 长图模式：以短边为 1080px 基准，避免长边限制导致单视频宽度过小。
            // 例如 2 路纵向叠加：画布 1080×3840 → 输出 1080×3840（每格 1080×1920，无质量损失）
            let shortSide = min(canvasW, canvasH)
            let longSide  = max(canvasW, canvasH)
            let maxShortSide: CGFloat = 1080
            let maxLongSide:  CGFloat = 4096  // HEVC 安全上限

            var scale = min(1.0, maxShortSide / shortSide)
            scale = min(scale, maxLongSide / longSide)

            w = (canvasW * scale / 2).rounded() * 2
            h = (canvasH * scale / 2).rounded() * 2
        } else {
            // 标准模式：长边 1080px（与原来行为一致）
            let maxSide: CGFloat = 1080
            let aspect = canvasW / canvasH
            if aspect >= 1.0 {
                let raw_w = maxSide
                let raw_h = (maxSide / aspect).rounded()
                w = (raw_w / 2).rounded() * 2
                h = (raw_h / 2).rounded() * 2
            } else {
                let raw_w = (maxSide * aspect).rounded()
                let raw_h = maxSide
                w = (raw_w / 2).rounded() * 2
                h = (raw_h / 2).rounded() * 2
            }
        }

        self.outputSize = CGSize(width: w, height: h)
        print("🎬 硬件合成器 v5 初始化: \(Int(outputSize.width))×\(Int(outputSize.height)), \(videoAssets.count) 路视频, isLongImage=\(config.isLongImage)")
    }

    // MARK: - Compose

    /// 主入口：合成带元数据的 Live Photo 视频到 outputURL
    func compose(outputURL: URL, assetIdentifier: String) throws {
        let t0 = Date()

        // Step 1: AVAssetReader(composition) + AVAssetWriter(H.264) → 严格 renderSize
        let rawURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lp_raw_\(UUID().uuidString).mov")
        try exportComposition(to: rawURL)
        print("✅ 合成完成: \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")

        // Step 2: 注入 Live Photo 元数据（透传压缩流）
        try injectLivePhotoMetadata(from: rawURL, to: outputURL, assetIdentifier: assetIdentifier)
        try? FileManager.default.removeItem(at: rawURL)
        print("✅ 全部完成: \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
    }

    // MARK: - Step 1: Export Composition

    private func exportComposition(to outputURL: URL) throws {
        try? FileManager.default.removeItem(at: outputURL)

        // 1a. 构建 AVMutableComposition，同时收集源轨道信息
        let composition = AVMutableComposition()
        var compositionTracks: [AVMutableCompositionTrack] = []
        var sourceTrackInfos: [SourceTrackInfo] = []

        for (i, asset) in videoAssets.enumerated() {
            guard let srcTrack = asset.tracks(withMediaType: .video).first else {
                throw CompositorError.noVideoTrack
            }

            // 显式保存源轨道信息，避免依赖 composition track 的属性继承
            let trackInfo = SourceTrackInfo(
                naturalSize: srcTrack.naturalSize,
                preferredTransform: srcTrack.preferredTransform
            )
            sourceTrackInfos.append(trackInfo)

            let t = srcTrack.preferredTransform
            print("📹 源视频 \(i+1): size=\(srcTrack.naturalSize)  pref=[a:\(f(t.a)) b:\(f(t.b)) c:\(f(t.c)) d:\(f(t.d)) tx:\(f(t.tx)) ty:\(f(t.ty))]")

            guard let compTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw CompositorError.compositionFailed
            }

            // 显式设置，不依赖自动继承
            compTrack.preferredTransform = srcTrack.preferredTransform

            let srcDuration = CMTimeMinimum(asset.duration, targetDuration)
            try compTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: srcDuration),
                of: srcTrack,
                at: .zero
            )

            // 短于 3 秒时定格最后一帧
            let assetSeconds = CMTimeGetSeconds(asset.duration)
            if assetSeconds < CMTimeGetSeconds(targetDuration) {
                let freezeStart = asset.duration
                let freezeDuration = targetDuration - asset.duration
                let lastFrameDuration = CMTime(value: 1, timescale: 30)
                let lastFrameStart = CMTimeSubtract(asset.duration, lastFrameDuration)
                try compTrack.insertTimeRange(
                    CMTimeRange(start: lastFrameStart, duration: lastFrameDuration),
                    of: srcTrack,
                    at: freezeStart
                )
                compTrack.scaleTimeRange(
                    CMTimeRange(start: freezeStart, duration: lastFrameDuration),
                    toDuration: freezeDuration
                )
            }

            compositionTracks.append(compTrack)
            print("📥 视频 \(i+1) 时长: \(String(format: "%.2f", assetSeconds))s")
        }

        // 1b. 构建布局变换（使用显式保存的源轨道信息）
        let videoComposition = buildVideoComposition(
            compositionTracks: compositionTracks,
            sourceTrackInfos: sourceTrackInfos
        )

        // 1c. AVAssetReader（读取合成帧，解码为 BGRA）
        // 使用这种方式可保证输出帧的尺寸 = renderSize，彻底解决黑边问题。
        let reader = try AVAssetReader(asset: composition)
        let readerOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: composition.tracks(withMediaType: .video),
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        readerOutput.videoComposition = videoComposition
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        // 1d. AVAssetWriter：长图用 HEVC（支持高分辨率），标准用 H.264
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        // 按像素数动态调整码率：基准 1080×1920 → 12 Mbps
        let basePixels: Double = 1080 * 1920
        let outPixels = Double(outputSize.width) * Double(outputSize.height)
        let bitrateScale = min(outPixels / basePixels, 4.0)  // 最大放大 4×
        let bitrate = Int(12_000_000 * bitrateScale)

        let videoSettings: [String: Any]
        if config.isLongImage {
            // HEVC：支持 4096px 以上分辨率，质量更好
            videoSettings = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: Int(outputSize.width),
                AVVideoHeightKey: Int(outputSize.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: bitrate,
                    AVVideoAllowFrameReorderingKey: false
                ]
            ]
        } else {
            videoSettings = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(outputSize.width),
                AVVideoHeightKey: Int(outputSize.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: bitrate,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoAllowFrameReorderingKey: false
                ]
            ]
        }
        print("🎥 编码: \(config.isLongImage ? "HEVC" : "H.264") \(Int(outputSize.width))×\(Int(outputSize.height)) @ \(bitrate/1_000_000)Mbps")
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: nil
        )
        writer.add(writerInput)

        guard reader.startReading() else {
            throw reader.error ?? CompositorError.readerStartFailed
        }
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // 1e. 逐帧处理（硬件编码，速度接近实时）
        var frameCount = 0
        let encodeQueue = DispatchQueue(label: "com.livepuzzle.encoder")
        let group = DispatchGroup()
        group.enter()

        writerInput.requestMediaDataWhenReady(on: encodeQueue) {
            while writerInput.isReadyForMoreMediaData {
                guard let sample = readerOutput.copyNextSampleBuffer() else {
                    writerInput.markAsFinished()
                    group.leave()
                    return
                }
                if let pb = CMSampleBufferGetImageBuffer(sample) {
                    // 第一帧：验证像素缓冲区尺寸是否与 renderSize 一致
                    if frameCount == 0 {
                        let pbW = CVPixelBufferGetWidth(pb)
                        let pbH = CVPixelBufferGetHeight(pb)
                        print("🖼️ 第一帧像素缓冲区: \(pbW)×\(pbH)，期望 renderSize: \(Int(self.outputSize.width))×\(Int(self.outputSize.height))")
                    }
                    let pts = CMSampleBufferGetPresentationTimeStamp(sample)
                    adaptor.append(pb, withPresentationTime: pts)
                    frameCount += 1
                }
            }
        }

        group.wait()

        if reader.status == .failed {
            throw reader.error ?? CompositorError.readerStartFailed
        }

        let finishSemaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { finishSemaphore.signal() }
        finishSemaphore.wait()

        if writer.status != .completed {
            throw writer.error ?? CompositorError.exportFailed
        }

        print("✅ 视频编码完成: \(Int(outputSize.width))x\(Int(outputSize.height)), \(frameCount) 帧")
    }

    // MARK: - Build Video Composition

    private func buildVideoComposition(
        compositionTracks: [AVMutableCompositionTrack],
        sourceTrackInfos: [SourceTrackInfo]
    ) -> AVMutableVideoComposition {

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = outputSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: targetDuration)

        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []

        for (i, track) in compositionTracks.enumerated() {
            guard i < config.blocks.count, i < sourceTrackInfos.count else { break }
            let block = config.blocks[i]
            let info = sourceTrackInfos[i]

            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)

            // 目标区域（输出像素坐标）
            let dstX = block.x * outputSize.width
            let dstY = block.y * outputSize.height
            let dstW = block.width * outputSize.width
            let dstH = block.height * outputSize.height

            // 用四个角点计算经 preferredTransform 变换后的实际显示尺寸
            // （比 CGSize.applying 更准确，能处理所有旋转/翻转组合）
            let pref = info.preferredTransform
            let nat = info.naturalSize
            let corners = [
                CGPoint.zero.applying(pref),
                CGPoint(x: nat.width, y: 0).applying(pref),
                CGPoint(x: 0, y: nat.height).applying(pref),
                CGPoint(x: nat.width, y: nat.height).applying(pref)
            ]
            let minX = corners.map(\.x).min()!
            let maxX = corners.map(\.x).max()!
            let minY = corners.map(\.y).min()!
            let maxY = corners.map(\.y).max()!
            let displayW = maxX - minX   // 显示宽（旋转后）
            let displayH = maxY - minY   // 显示高（旋转后）

            guard displayW > 0, displayH > 0 else {
                print("⚠️ Block \(i) 显示尺寸为零，跳过")
                continue
            }

            // BoxFit.cover：取更大的缩放比保证完全覆盖目标区域
            // 同时叠加用户的额外缩放（block.scale，默认 1.0）
            let userScale = max(block.scale, 1.0)
            let coverScale = max(dstW / displayW, dstH / displayH) * userScale

            // 居中裁剪偏移：缩放后的显示尺寸超出目标区域的部分居中裁掉
            // 同时叠加用户的平移（block.offsetX/Y，单位为画布像素，需折算）
            let scaledDisplayW = displayW * coverScale
            let scaledDisplayH = displayH * coverScale
            let panX = block.offsetX / config.canvasWidth * outputSize.width
            let panY = block.offsetY / config.canvasHeight * outputSize.height
            let cropOffsetX = (scaledDisplayW - dstW) / 2.0 - panX
            let cropOffsetY = (scaledDisplayH - dstH) / 2.0 - panY

            // pref 可能包含平移（让旋转后的视频保持在正坐标区域）
            // 连接顺序：原始旋转 → cover 缩放 → 目标平移
            // 注意：concatenating 会把 pref 的 tx/ty 也一起缩放，效果等同于
            //   先应用 pref（旋转+平移），再整体缩放，再整体平移到目标位置
            let finalTransform = pref
                .concatenating(CGAffineTransform(scaleX: coverScale, y: coverScale))
                .concatenating(CGAffineTransform(
                    translationX: dstX - cropOffsetX,
                    y: dstY - cropOffsetY
                ))

            layer.setTransform(finalTransform, at: .zero)

            // setCropRectangle 在 track space（源视频坐标）生效，而非 output space。
            // 将 dstRect 对应的 display-space 区域通过 pref 的逆变换映射回 track space。
            // display-space 中，对应 dstRect 的区域边界：
            let displayCropX0 = minX + cropOffsetX / coverScale
            let displayCropY0 = minY + cropOffsetY / coverScale
            let displayCropX1 = minX + (cropOffsetX + dstW) / coverScale
            let displayCropY1 = minY + (cropOffsetY + dstH) / coverScale

            let invPref = pref.inverted()
            let trackPts = [
                CGPoint(x: displayCropX0, y: displayCropY0).applying(invPref),
                CGPoint(x: displayCropX1, y: displayCropY0).applying(invPref),
                CGPoint(x: displayCropX0, y: displayCropY1).applying(invPref),
                CGPoint(x: displayCropX1, y: displayCropY1).applying(invPref)
            ]
            let trackCropRect = CGRect(
                x: trackPts.map(\.x).min()!,
                y: trackPts.map(\.y).min()!,
                width:  trackPts.map(\.x).max()! - trackPts.map(\.x).min()!,
                height: trackPts.map(\.y).max()! - trackPts.map(\.y).min()!
            ).intersection(CGRect(origin: .zero, size: nat))
            layer.setCropRectangle(trackCropRect, at: .zero)

            print("📐 Block \(i): dst(\(Int(dstX)),\(Int(dstY)),\(Int(dstW))×\(Int(dstH))) display(\(Int(displayW))×\(Int(displayH))) scale=\(String(format:"%.3f", coverScale))")

            layerInstructions.append(layer)
        }

        instruction.layerInstructions = layerInstructions
        videoComposition.instructions = [instruction]
        return videoComposition
    }

    // MARK: - Step 2: Inject Live Photo Metadata

    private func injectLivePhotoMetadata(
        from rawURL: URL,
        to outputURL: URL,
        assetIdentifier: String
    ) throws {
        try? FileManager.default.removeItem(at: outputURL)

        let srcAsset = AVAsset(url: rawURL)

        // ── Reader ──
        let reader = try AVAssetReader(asset: srcAsset)
        guard let srcVideoTrack = srcAsset.tracks(withMediaType: .video).first else {
            throw CompositorError.noVideoTrack
        }
        print("📏 透传视频尺寸: \(srcVideoTrack.naturalSize)")
        let readerOutput = AVAssetReaderTrackOutput(
            track: srcVideoTrack,
            outputSettings: nil  // 透传压缩数据
        )
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)
        guard reader.startReading() else {
            throw reader.error ?? CompositorError.readerStartFailed
        }

        // ── Writer ──
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        // 容器元数据
        let contentIdItem = AVMutableMetadataItem()
        contentIdItem.key = "com.apple.quicktime.content.identifier" as NSString
        contentIdItem.keySpace = AVMetadataKeySpace.quickTimeMetadata
        contentIdItem.value = assetIdentifier as NSString
        contentIdItem.dataType = "com.apple.metadata.datatype.UTF-8"
        writer.metadata = [contentIdItem]

        // 视频轨道（透传）
        guard let formatDesc = srcVideoTrack.formatDescriptions.first else {
            throw CompositorError.noVideoTrack
        }
        let writerInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: nil,
            sourceFormatHint: formatDesc as! CMFormatDescription
        )
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        // still-image-time 元数据轨道
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
        var metaAdaptor: AVAssetWriterInputMetadataAdaptor?
        if let desc = metaFormatDesc {
            let metaInput = AVAssetWriterInput(
                mediaType: .metadata,
                outputSettings: nil,
                sourceFormatHint: desc
            )
            metaAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metaInput)
            writer.add(metaInput)
        }

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // 写入 still-image-time
        if let adaptor = metaAdaptor {
            let coverTimeMs = config.coverTimes.first ?? 0
            let coverTime = CMTime(value: CMTimeValue(coverTimeMs), timescale: 1000)
            let frameDuration = CMTime(value: 1, timescale: 30)
            let stillItem = AVMutableMetadataItem()
            stillItem.key = "com.apple.quicktime.still-image-time" as NSString
            stillItem.keySpace = AVMetadataKeySpace.quickTimeMetadata
            stillItem.value = NSNumber(value: 0)
            stillItem.dataType = "com.apple.metadata.datatype.int8"
            let group = AVTimedMetadataGroup(
                items: [stillItem],
                timeRange: CMTimeRange(start: coverTime, duration: frameDuration)
            )
            adaptor.append(group)
            adaptor.assetWriterInput.markAsFinished()
        }

        // 拷贝压缩视频帧
        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }
            writerInput.append(sampleBuffer)
        }
        writerInput.markAsFinished()
        reader.cancelReading()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()

        if writer.status != .completed {
            throw writer.error ?? CompositorError.encodingFailed
        }

        let size = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? UInt64) ?? 0
        print("✅ 元数据注入完成，文件大小: \(size / 1024) KB")
    }

    // MARK: - Helpers

    private func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
}

// MARK: - Errors

enum CompositorError: Error {
    case metalNotAvailable
    case bufferPoolCreationFailed
    case compositionFailed
    case encoderNotReady
    case encodingFailed
    case noVideoTrack
    case readerStartFailed
    case coverExtractionFailed
    case exportSessionFailed
    case exportFailed

    var localizedDescription: String {
        switch self {
        case .metalNotAvailable: return "Metal GPU not available"
        case .bufferPoolCreationFailed: return "Failed to create pixel buffer pool"
        case .compositionFailed: return "Frame composition failed"
        case .encoderNotReady: return "Hardware encoder not ready"
        case .encodingFailed: return "Video encoding failed"
        case .noVideoTrack: return "No video track found"
        case .readerStartFailed: return "Failed to start asset reader"
        case .coverExtractionFailed: return "Failed to extract cover frame"
        case .exportSessionFailed: return "Failed to create export session"
        case .exportFailed: return "Export failed"
        }
    }
}

// MARK: - Int extension

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
