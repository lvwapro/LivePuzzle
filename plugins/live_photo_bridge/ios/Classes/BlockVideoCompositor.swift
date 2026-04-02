import AVFoundation
import CoreImage

/// 自定义视频合成器：在 display 空间用 CIImage 做 BoxFit.cover 合成
final class BlockVideoCompositor: NSObject, AVVideoCompositing {

    struct TrackInfo {
        let trackID: CMPersistentTrackID
        let blockIndex: Int
        let preferredTransform: CGAffineTransform
    }

    struct Setup {
        let trackInfos: [TrackInfo]
        let config: HardwareVideoCompositor.CompositorConfig
        let outputSize: CGSize
    }

    static var pendingSetup: Setup?

    private let setup: Setup

    private lazy var ciContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        }
        return CIContext(options: [.useSoftwareRenderer: false])
    }()

    // MARK: AVVideoCompositing Protocol

    var sourcePixelBufferAttributes: [String: Any]? {
        [kCVPixelBufferPixelFormatTypeKey as String: [
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_32BGRA
        ]]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: Any] {
        [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }

    override init() {
        guard let s = BlockVideoCompositor.pendingSetup else {
            fatalError("BlockVideoCompositor.pendingSetup 必须在实例化前设置")
        }
        setup = s
        super.init()
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) { }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let outBuf = request.renderContext.newPixelBuffer() else {
            request.finish(with: CompositorError.compositionFailed)
            return
        }

        let renderSize = setup.outputSize

        CVPixelBufferLockBaseAddress(outBuf, [])
        defer { CVPixelBufferUnlockBaseAddress(outBuf, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(outBuf),
            width: Int(renderSize.width),
            height: Int(renderSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(outBuf),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            request.finish(with: CompositorError.compositionFailed)
            return
        }

        // 填充背景色
        ctx.setFillColor(setup.config.backgroundColor.cgColor)
        ctx.fill(CGRect(origin: .zero, size: renderSize))

        for info in setup.trackInfos {
            guard info.blockIndex < setup.config.blocks.count else { continue }
            let block = setup.config.blocks[info.blockIndex]
            guard let srcBuf = request.sourceFrame(byTrackID: info.trackID) else { continue }
            drawBlock(src: srcBuf, pref: info.preferredTransform, block: block,
                      ctx: ctx, renderSize: renderSize)
        }

        request.finish(withComposedVideoFrame: outBuf)
    }

    func cancelAllPendingVideoCompositionRequests() { }

    // MARK: Per-Block Compositing

    private func drawBlock(
        src: CVPixelBuffer,
        pref: CGAffineTransform,
        block: HardwareVideoCompositor.LayoutBlock,
        ctx: CGContext,
        renderSize: CGSize
    ) {
        var ciImg = CIImage(cvPixelBuffer: src).transformed(by: pref)

        let o = ciImg.extent.origin
        if o.x != 0 || o.y != 0 {
            ciImg = ciImg.transformed(by: CGAffineTransform(translationX: -o.x, y: -o.y))
        }

        // preferredTransform 是 y-down 坐标系，CIImage 是 y-up，含旋转时补 180° 修正
        if pref.b != 0 || pref.c != 0 {
            let w = ciImg.extent.width
            let h = ciImg.extent.height
            ciImg = ciImg.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: w, ty: h))
        }

        let imgW = ciImg.extent.width
        let imgH = ciImg.extent.height
        guard imgW > 0, imgH > 0 else { return }

        let dstX = CGFloat(block.x) * renderSize.width
        let dstY = CGFloat(block.y) * renderSize.height
        let dstW = max(1, CGFloat(block.width)  * renderSize.width)
        let dstH = max(1, CGFloat(block.height) * renderSize.height)

        let userScale  = max(CGFloat(block.scale), 0.1)
        let coverScale = max(dstW / imgW, dstH / imgH) * userScale

        let isRotated = pref.b != 0 || pref.c != 0
        let panX = CGFloat(block.offsetX) / CGFloat(setup.config.canvasWidth)  * renderSize.width
        let panY = CGFloat(block.offsetY) / CGFloat(setup.config.canvasHeight) * renderSize.height
        let cropOffsetX = (imgW * coverScale - dstW) / 2.0 - panX
        let cropOffsetY = (imgH * coverScale - dstH) / 2.0 + (isRotated ? panY : -panY)

        let srcX = max(0.0, cropOffsetX / coverScale)
        let srcY = max(0.0, cropOffsetY / coverScale)
        let srcW = max(1.0, min(imgW - srcX, dstW / coverScale))
        let srcH = max(1.0, min(imgH - srcY, dstH / coverScale))

        let cgY = renderSize.height - dstY - dstH
        let clipRect = CGRect(x: dstX, y: cgY, width: dstW, height: dstH)
        let radiusPx = CGFloat(setup.config.cornerRadius) /
            CGFloat(setup.config.canvasWidth) * renderSize.width

        ctx.saveGState()
        if radiusPx > 0 {
            let path = CGPath(roundedRect: clipRect, cornerWidth: radiusPx,
                              cornerHeight: radiusPx, transform: nil)
            ctx.addPath(path)
            ctx.clip()
        } else {
            ctx.clip(to: clipRect)
        }

        if let cgImg = ciContext.createCGImage(ciImg, from: CGRect(x: srcX, y: srcY, width: srcW, height: srcH)) {
            ctx.draw(cgImg, in: CGRect(x: dstX, y: cgY, width: srcW * coverScale, height: srcH * coverScale))
        }

        ctx.restoreGState()
    }
}

// MARK: - Errors

enum CompositorError: Error {
    case compositionFailed
    case encodingFailed
    case noVideoTrack
    case readerStartFailed
    case exportFailed

    var localizedDescription: String {
        switch self {
        case .compositionFailed: return "Frame composition failed"
        case .encodingFailed: return "Video encoding failed"
        case .noVideoTrack: return "No video track found"
        case .readerStartFailed: return "Failed to start asset reader"
        case .exportFailed: return "Export failed"
        }
    }
}
