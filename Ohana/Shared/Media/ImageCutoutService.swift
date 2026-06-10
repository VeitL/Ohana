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
    init() {}

    // MARK: - 主入口
    /// 将图片主体前景抠出，背景替换为透明，返回 PNG 格式的 UIImage
    func removeBackground(from image: UIImage) async throws -> UIImage? {
        guard image.cgImage != nil else { return nil }

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
        let width = CVPixelBufferGetWidth(mask)
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

        guard context.makeImage() != nil else { return nil }

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
        for row in 0 ..< height {
            let maskRowPtr = maskBase.advanced(by: row * maskBytesPerRow).bindMemory(to: UInt8.self, capacity: width)
            for col in 0 ..< width {
                let maskVal = maskRowPtr[col]
                let srcIdx = (row * width + col) * 4
                let alpha = maskVal > 128 ? UInt8(255) : UInt8(0)
                outputBytes[srcIdx] = sourceBytes[srcIdx] // R
                outputBytes[srcIdx + 1] = sourceBytes[srcIdx + 1] // G
                outputBytes[srcIdx + 2] = sourceBytes[srcIdx + 2] // B
                outputBytes[srcIdx + 3] = alpha // A
            }
        }

        guard let outputCG = outputContext.makeImage() else { return nil }
        return UIImage(cgImage: outputCG)
    }

    // MARK: - FIX 3-C: 透明像素检测
    /// 检测 Data 是否真的包含透明像素。普通相册 PNG 往往带 alpha 通道但全部不透明，
    /// 不能把它误判成「粘贴主体」抠图。
    nonisolated static func isTransparentPNG(_ data: Data) -> Bool {
        guard let image = UIImage(data: data) else { return false } // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
        return imageHasTransparentPixels(image)
    }

    nonisolated static func imageHasTransparentPixels(_ image: UIImage, alphaThreshold: UInt8 = 245) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let alpha = cgImage.alphaInfo
        guard alpha != .none, alpha != .noneSkipFirst, alpha != .noneSkipLast else { return false }

        let sourceW = cgImage.width
        let sourceH = cgImage.height
        guard sourceW > 0, sourceH > 0 else { return false }

        let maxSampleDim = 160
        let sampleScale = min(CGFloat(maxSampleDim) / CGFloat(max(sourceW, sourceH)), 1)
        let sampleW = max(1, Int(CGFloat(sourceW) * sampleScale))
        let sampleH = max(1, Int(CGFloat(sourceH) * sampleScale))
        let bytesPerRow = sampleW * 4
        let pixelBufferCount = sampleH * bytesPerRow
        var pixels = [UInt8](repeating: 0, count: pixelBufferCount)

        return pixels.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                      data: baseAddress,
                      width: sampleW,
                      height: sampleH,
                      bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }

            context.interpolationQuality = .low
            context.clear(CGRect(x: 0, y: 0, width: sampleW, height: sampleH))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleW, height: sampleH))

            let buffer = rawBuffer.bindMemory(to: UInt8.self)
            var transparentCount = 0
            var opaqueMinX = sampleW
            var opaqueMinY = sampleH
            var opaqueMaxX = -1
            var opaqueMaxY = -1

            for y in 0 ..< sampleH {
                let rowStart = y * bytesPerRow
                for x in 0 ..< sampleW {
                    let alpha = buffer[rowStart + x * 4 + 3]
                    if alpha < alphaThreshold {
                        transparentCount += 1
                    } else {
                        opaqueMinX = min(opaqueMinX, x)
                        opaqueMinY = min(opaqueMinY, y)
                        opaqueMaxX = max(opaqueMaxX, x)
                        opaqueMaxY = max(opaqueMaxY, y)
                    }
                }
            }

            guard transparentCount > 0 else { return false }
            guard opaqueMaxX >= 0, opaqueMaxY >= 0 else { return true }

            let totalPixels = max(1, sampleW * sampleH)
            let transparentRatio = Double(transparentCount) / Double(totalPixels)
            guard transparentRatio >= 0.015 else { return false }

            let opaqueWidth = opaqueMaxX - opaqueMinX + 1
            let opaqueHeight = opaqueMaxY - opaqueMinY + 1
            let fillsCanvas = Double(opaqueWidth) / Double(sampleW) >= 0.94
                && Double(opaqueHeight) / Double(sampleH) >= 0.94

            // A rounded/circular real photo can have transparent corners while
            // still filling the card visually. Keep those as photo cards; reserve
            // popout rendering for meaningful transparent backdrops.
            if fillsCanvas, transparentRatio < 0.28 {
                return false
            }
            return true
        }
    }

    nonisolated static func trimmedTransparentSubjectImage(from image: UIImage, alphaThreshold: UInt8 = 12) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return image }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        let bounds = pixels.withUnsafeMutableBytes { rawBuffer -> CGRect? in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                      data: baseAddress,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return nil
            }

            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            let buffer = rawBuffer.bindMemory(to: UInt8.self)
            var minX = width
            var minY = height
            var maxX = -1
            var maxY = -1

            for y in 0 ..< height {
                let rowStart = y * bytesPerRow
                for x in 0 ..< width {
                    let alpha = buffer[rowStart + x * bytesPerPixel + 3]
                    guard alpha > alphaThreshold else { continue }
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }

            guard maxX >= minX, maxY >= minY else { return nil }

            let sidePadding = max(2, Int(CGFloat(max(width, height)) * 0.015))
            let cropX = max(0, minX - sidePadding)
            let cropY = max(0, minY - sidePadding)
            let cropMaxX = min(width - 1, maxX + sidePadding)

            return CGRect(
                x: cropX,
                y: cropY,
                width: cropMaxX - cropX + 1,
                height: maxY - cropY + 1
            )
        }

        guard let bounds else { return image }
        let cropX = Int(bounds.origin.x)
        let cropY = Int(bounds.origin.y)
        let cropW = Int(bounds.width)
        let cropH = Int(bounds.height)
        guard cropW > 0, cropH > 0 else { return image }

        var croppedPixels = [UInt8](repeating: 0, count: cropW * cropH * bytesPerPixel)
        for row in 0 ..< cropH {
            let srcStart = (cropY + row) * bytesPerRow + cropX * bytesPerPixel
            let dstStart = row * cropW * bytesPerPixel
            croppedPixels[dstStart ..< (dstStart + cropW * bytesPerPixel)] =
                pixels[srcStart ..< (srcStart + cropW * bytesPerPixel)]
        }

        return croppedPixels.withUnsafeMutableBytes { rawBuffer -> UIImage? in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                      data: baseAddress,
                      width: cropW,
                      height: cropH,
                      bitsPerComponent: 8,
                      bytesPerRow: cropW * bytesPerPixel,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ),
                  let croppedCGImage = context.makeImage()
            else {
                return image
            }

            return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: .up)
        }
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
