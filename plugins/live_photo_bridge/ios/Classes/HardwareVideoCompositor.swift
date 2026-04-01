import AVFoundation
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

        // 校验：blocks 数量与视频数量一致
        guard config.blocks.count == videoAssets.count else {
            throw CompositorError.compositionFailed
        }
        let f = { (x: CGFloat) in String(format: "%.2f", x) }
        for (index, asset) in videoAssets.enumerated() {
            guard let tr = asset.tracks(withMediaType: .video).first else {
                throw CompositorError.noVideoTrack
            }
            let dur = CMTimeGetSeconds(asset.duration)
            let t = tr.preferredTransform
            print("📹 视频 \(index): \(Int(tr.naturalSize.width))×\(Int(tr.naturalSize.height)), 时长 \(String(format: "%.2f", dur))s pref a=\(f(t.a)) b=\(f(t.b)) c=\(f(t.c)) d=\(f(t.d)) tx=\(f(t.tx)) ty=\(f(t.ty))")
        }

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
            let maxSide: CGFloat = 1920
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

        for (i, block) in config.blocks.enumerated() {
            if block.x < 0 || block.y < 0 || block.x + block.width > 1.0 || block.y + block.height > 1.0 {
                print("⚠️ 块 \(i) 超出画布: x=\(block.x) y=\(block.y) w=\(block.width) h=\(block.height)")
            }
            if block.width <= 0 || block.height <= 0 {
                print("⚠️ 块 \(i) 尺寸无效: w=\(block.width) h=\(block.height)")
            }
        }

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
                        
                        // 检测第一帧是否为黑屏
                        CVPixelBufferLockBaseAddress(pb, .readOnly)
                        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
                        
                        if let baseAddress = CVPixelBufferGetBaseAddress(pb) {
                            let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
                            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
                            
                            // 采样中心区域的像素来检测是否全黑
                            let centerY = pbH / 2
                            let centerX = pbW / 2
                            let sampleSize = min(100, min(pbW, pbH) / 4)
                            
                            var totalBrightness: Int = 0
                            var sampleCount = 0
                            
                            for y in (centerY - sampleSize/2)..<(centerY + sampleSize/2) {
                                for x in (centerX - sampleSize/2)..<(centerX + sampleSize/2) {
                                    let offset = y * bytesPerRow + x * 4
                                    let r = Int(buffer[offset + 1])
                                    let g = Int(buffer[offset + 2])
                                    let b = Int(buffer[offset + 3])
                                    totalBrightness += (r + g + b) / 3
                                    sampleCount += 1
                                }
                            }
                            
                            let avgBrightness = sampleCount > 0 ? totalBrightness / sampleCount : 0
                            if avgBrightness < 10 {
                                print("⚠️ 警告：第一帧中心区域几乎全黑（亮度: \(avgBrightness)/255）")
                            } else {
                                print("✅ 第一帧亮度正常（平均亮度: \(avgBrightness)/255）")
                            }
                        }
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

        print("📐 [合成] renderSize=\(Int(outputSize.width))×\(Int(outputSize.height)) isLongImage=\(config.isLongImage) blocks=\(config.blocks.count)")

        // 使用自定义合成器：完全绕过 setCropRectangle/setTransform 坐标系问题
        // 由 BlockVideoCompositor 在 display 空间用 CIImage 做 BoxFit.cover 合成
        let trackInfos = compositionTracks.enumerated().map { (i, track) in
            BlockVideoCompositor.TrackInfo(
                trackID: track.trackID,
                blockIndex: i,
                preferredTransform: sourceTrackInfos[i].preferredTransform
            )
        }
        BlockVideoCompositor.pendingSetup = BlockVideoCompositor.Setup(
            trackInfos: trackInfos,
            config: config,
            outputSize: outputSize
        )
        videoComposition.customVideoCompositorClass = BlockVideoCompositor.self

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: targetDuration)

        // 即使使用自定义合成器，也需要 layerInstructions 告知 AVFoundation 要提供哪些轨道帧
        instruction.layerInstructions = compositionTracks.map { track in
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            layer.setOpacity(1.0, at: .zero)
            return layer
        }

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
