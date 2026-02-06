import Flutter
import UIKit
import Photos
import AVFoundation

public class LivePhotoPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "live_puzzle/live_photo",
            binaryMessenger: registrar.messenger()
        )
        let instance = LivePhotoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let frameChannel = FlutterMethodChannel(
            name: "live_puzzle/frame_extractor",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: frameChannel)
        
        let creatorChannel = FlutterMethodChannel(
            name: "live_puzzle/creator",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: creatorChannel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isLivePhoto":
            handleIsLivePhoto(call, result: result)
        case "extractVideo":
            handleExtractVideo(call, result: result)
        case "getVideoDuration":
            handleGetVideoDuration(call, result: result)
        case "getVideoFrameCount":
            handleGetVideoFrameCount(call, result: result)
        case "extractFrameAtTime":
            handleExtractFrameAtTime(call, result: result)
        case "extractFrameAtIndex":
            handleExtractFrameAtIndex(call, result: result)
        case "extractFrames":
            handleExtractFrames(call, result: result)
        case "extractKeyFrames":
            handleExtractKeyFrames(call, result: result)
        case "createVideoFromFrames":
            handleCreateVideoFromFrames(call, result: result)
        case "createLivePhoto":
            handleCreateLivePhoto(call, result: result)
        case "saveToGallery":
            handleSaveToGallery(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleIsLivePhoto(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let assetId = args["assetId"] as? String else {
            result(false)
            return
        }
        
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetId],
            options: nil
        )
        
        guard let asset = fetchResult.firstObject else {
            result(false)
            return
        }
        
        result(asset.mediaSubtypes.contains(.photoLive))
    }
    
    private func handleExtractVideo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let assetId = args["assetId"] as? String else {
            result(nil)
            return
        }
        
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetId],
            options: nil
        )
        
        guard let asset = fetchResult.firstObject,
              asset.mediaSubtypes.contains(.photoLive) else {
            result(nil)
            return
        }
        
        let resources = PHAssetResource.assetResources(for: asset)
        guard let videoResource = resources.first(where: {
            $0.type == .pairedVideo
        }) else {
            result(nil)
            return
        }
        
        let tempDir = NSTemporaryDirectory()
        let videoPath = (tempDir as NSString).appendingPathComponent(
            "live_video_\(UUID().uuidString).mov"
        )
        
        let options = PHAssetResourceRequestOptions()
        PHAssetResourceManager.default().writeData(
            for: videoResource,
            toFile: URL(fileURLWithPath: videoPath),
            options: options
        ) { error in
            if error != nil {
                result(nil)
            } else {
                result(videoPath)
            }
        }
    }
    
    private func handleGetVideoDuration(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoPath = args["videoPath"] as? String else {
            result(3000)
            return
        }
        
        let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
        let duration = CMTimeGetSeconds(asset.duration) * 1000
        result(Int(duration))
    }
    
    private func handleGetVideoFrameCount(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoPath = args["videoPath"] as? String else {
            result(30)
            return
        }
        
        let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
        guard let track = asset.tracks(withMediaType: .video).first else {
            result(30)
            return
        }
        
        let duration = CMTimeGetSeconds(asset.duration)
        let frameRate = track.nominalFrameRate
        result(Int(duration * Double(frameRate)))
    }
    
    private func handleExtractFrameAtTime(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoPath = args["videoPath"] as? String,
              let timestamp = args["timestamp"] as? Int else {
            result(nil)
            return
        }
        
        let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        let time = CMTime(value: Int64(timestamp), timescale: 1000)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            
            guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                result(nil)
                return
            }
            
            let frameData: [String: Any] = [
                "index": 0,
                "timestamp": timestamp,
                "imageData": FlutterStandardTypedData(bytes: imageData),
                "width": cgImage.width,
                "height": cgImage.height
            ]
            result(frameData)
        } catch {
            print("提取帧失败: \(error)")
            result(nil)
        }
    }
    
    private func handleExtractFrameAtIndex(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(nil)
    }
    
    private func handleExtractFrames(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result([])
    }
    
    private func handleExtractKeyFrames(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result([])
    }
    
    private func handleCreateVideoFromFrames(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let framePaths = args["framePaths"] as? [String],
              let outputPath = args["outputPath"] as? String,
              let fps = args["fps"] as? Int else {
            result(false)
            return
        }
        
        createVideo(from: framePaths, outputPath: outputPath, fps: fps) { success in
            result(success)
        }
    }
    
    private func createVideo(from imagePaths: [String], outputPath: String, fps: Int, completion: @escaping (Bool) -> Void) {
        guard !imagePaths.isEmpty else {
            completion(false)
            return
        }
        
        // 获取第一张图片的尺寸
        guard let firstImage = UIImage(contentsOfFile: imagePaths[0]) else {
            completion(false)
            return
        }
        
        let videoSize = firstImage.size
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // 删除已存在的文件
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            completion(false)
            return
        }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height
        ]
        
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: nil
        )
        
        videoWriter.add(videoWriterInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        let frameDuration = CMTime(value: 1, timescale: Int32(fps))
        var frameCount = 0
        
        for imagePath in imagePaths {
            autoreleasepool {
                guard let image = UIImage(contentsOfFile: imagePath),
                      let pixelBuffer = image.pixelBuffer(width: Int(videoSize.width), height: Int(videoSize.height)) else {
                    return
                }
                
                while !videoWriterInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.1)
                }
                
                let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                frameCount += 1
            }
        }
        
        videoWriterInput.markAsFinished()
        videoWriter.finishWriting {
            completion(videoWriter.status == .completed)
        }
    }
    
    private func handleCreateLivePhoto(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String,
              let videoPath = args["videoPath"] as? String,
              let outputPath = args["outputPath"] as? String else {
            result(false)
            return
        }
        
        // 复制视频到输出路径
        let videoURL = URL(fileURLWithPath: videoPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        try? FileManager.default.removeItem(at: outputURL)
        try? FileManager.default.copyItem(at: videoURL, to: outputURL)
        
        result(true)
    }
    
    private func handleSaveToGallery(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(false)
            return
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        }) { success, error in
            if let error = error {
                print("保存失败: \(error)")
            }
            result(success)
        }
    }
}

extension UIImage {
    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        
        return buffer
    }
}
