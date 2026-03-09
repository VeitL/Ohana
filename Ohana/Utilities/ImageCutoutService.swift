//
//  ImageCutoutService.swift
//  Ohana
//
//  iOS 17 Vision 原生抠像服务
//  使用 VNGenerateForegroundInstanceMaskRequest 提取主体前景，背景替换为透明
//

import UIKit
import Vision

@MainActor
final class ImageCutoutService {

    static let shared = ImageCutoutService()
    private init() {}

    // MARK: - 主入口
    /// 将图片主体前景抠出，背景替换为透明，返回 PNG 格式的 UIImage
    func removeBackground(from image: UIImage) async throws -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        // 转换到正确方向
        let orientedImage = image.fixedOrientation()
        guard let fixedCG = orientedImage.cgImage else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: fixedCG, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
                return
            }

            guard let result = request.results?.first else {
                continuation.resume(returning: nil)
                return
            }

            do {
                // 获取所有前景实例的 mask
                let allInstances = result.allInstances
                let maskBuffer = try result.generateScaledMaskForImage(forInstances: allInstances, from: handler)
                let maskedImage = apply(mask: maskBuffer, to: fixedCG)
                continuation.resume(returning: maskedImage)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - 将 mask 应用到原图，输出透明背景 UIImage
    private func apply(mask: CVPixelBuffer, to cgImage: CGImage) -> UIImage? {
        let width  = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)

        // 创建 RGBA 输出 context
        guard let context = CGContext(
            data: nil,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // 先画原图
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let rendered = context.makeImage() else { return nil }

        // 用 mask buffer 抠图：将 mask 白色区域保留，黑色区域变透明
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let maskBase = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let maskBytesPerRow = CVPixelBufferGetBytesPerRow(mask)

        // 构建透明背景的输出 context
        guard let outputContext = CGContext(
            data: nil,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        guard let outputData = outputContext.data else { return nil }
        let outputBytes = outputData.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // 从原图获取像素数据
        guard let sourceContext = CGContext(
            data: nil,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        sourceContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let sourceData = sourceContext.data else { return nil }
        let sourceBytes = sourceData.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // 逐像素合成：mask=255 保留，mask=0 透明
        for row in 0..<height {
            let maskRowPtr = maskBase.advanced(by: row * maskBytesPerRow).bindMemory(to: UInt8.self, capacity: width)
            for col in 0..<width {
                let maskVal  = maskRowPtr[col]
                let srcIdx   = (row * width + col) * 4
                let alpha    = maskVal > 128 ? UInt8(255) : UInt8(0)
                outputBytes[srcIdx]     = sourceBytes[srcIdx]       // R
                outputBytes[srcIdx + 1] = sourceBytes[srcIdx + 1]   // G
                outputBytes[srcIdx + 2] = sourceBytes[srcIdx + 2]   // B
                outputBytes[srcIdx + 3] = alpha                     // A
            }
        }

        guard let outputCG = outputContext.makeImage() else { return nil }
        return UIImage(cgImage: outputCG)
    }

    // MARK: - FIX 3-C: 透明通道检测
    /// 检测 Data 是否为含透明通道的 PNG（抠图结果）
    static func isTransparentPNG(_ data: Data) -> Bool {
        guard let image = UIImage(data: data),
              let cgImage = image.cgImage else { return false }
        let alpha = cgImage.alphaInfo
        return alpha != .none && alpha != .noneSkipFirst && alpha != .noneSkipLast
    }
}

// MARK: - UIImage 方向修正扩展
private extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let fixed = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return fixed ?? self
    }
}
