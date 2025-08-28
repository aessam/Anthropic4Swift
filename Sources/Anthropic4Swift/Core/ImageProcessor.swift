import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct ImageProcessor {
    public static let maxImageSize = CGSize(width: 1568, height: 1568)
    public static let jpegQuality: CGFloat = 0.8
    
    public static func processImage(_ cgImage: CGImage, maxSize: CGSize = maxImageSize) -> ContentBlock? {
        let resizedImage = resizeImage(cgImage, to: maxSize)
        
        guard let imageData = encodeImageAsJPEG(resizedImage, quality: jpegQuality) else {
            return nil
        }
        
        let base64String = imageData.base64EncodedString()
        
        return .image(ContentBlock.ImageBlock(
            source: ContentBlock.ImageBlock.ImageSource(
                mediaType: "image/jpeg",
                data: base64String
            )
        ))
    }
    
    public static func processImageData(
        _ data: Data,
        mimeType: String,
        maxSize: CGSize = maxImageSize
    ) -> ContentBlock? {
        guard let cgImage = createCGImage(from: data) else {
            return nil
        }
        
        let resizedImage = resizeImage(cgImage, to: maxSize)
        
        let outputMimeType: String
        let outputData: Data
        
        if mimeType.lowercased().contains("png") {
            outputMimeType = "image/png"
            guard let pngData = encodeImageAsPNG(resizedImage) else { return nil }
            outputData = pngData
        } else {
            outputMimeType = "image/jpeg"
            guard let jpegData = encodeImageAsJPEG(resizedImage, quality: jpegQuality) else { return nil }
            outputData = jpegData
        }
        
        let base64String = outputData.base64EncodedString()
        
        return .image(ContentBlock.ImageBlock(
            source: ContentBlock.ImageBlock.ImageSource(
                mediaType: outputMimeType,
                data: base64String
            )
        ))
    }
    
    private static func resizeImage(_ cgImage: CGImage, to maxSize: CGSize) -> CGImage {
        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        let scaleFactor = min(
            maxSize.width / originalSize.width,
            maxSize.height / originalSize.height,
            1.0
        )
        
        if scaleFactor >= 1.0 {
            return cgImage
        }
        
        let newSize = CGSize(
            width: originalSize.width * scaleFactor,
            height: originalSize.height * scaleFactor
        )
        
        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: Int(newSize.width),
                height: Int(newSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return cgImage
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: newSize))
        
        return context.makeImage() ?? cgImage
    }
    
    private static func createCGImage(from data: Data) -> CGImage? {
        guard let dataProvider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                jpegDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) ?? CGImage(
                pngDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }
        return cgImage
    }
    
    private static func encodeImageAsJPEG(_ cgImage: CGImage, quality: CGFloat) -> Data? {
        let mutableData = NSMutableData()
        
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            return nil
        }
        
        let options = [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary
        
        CGImageDestinationAddImage(destination, cgImage, options)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
    
    private static func encodeImageAsPNG(_ cgImage: CGImage) -> Data? {
        let mutableData = NSMutableData()
        
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            "public.png" as CFString,
            1,
            nil
        ) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
}

public struct Image: ContentBlockConvertible {
    private let cgImage: CGImage
    private let maxSize: CGSize
    
    public init(_ cgImage: CGImage, maxSize: CGSize = ImageProcessor.maxImageSize) {
        self.cgImage = cgImage
        self.maxSize = maxSize
    }
    
    public func toContentBlock() -> ContentBlock {
        return ImageProcessor.processImage(cgImage, maxSize: maxSize) ?? .text("[Image processing failed]")
    }
}

#if canImport(UIKit)
extension Image {
    public init(_ uiImage: UIImage, maxSize: CGSize = ImageProcessor.maxImageSize) {
        guard let cgImage = uiImage.cgImage else {
            self.init(UIImage().cgImage!, maxSize: maxSize)
            return
        }
        self.init(cgImage, maxSize: maxSize)
    }
}
#endif

#if canImport(AppKit)
extension Image {
    public init(_ nsImage: NSImage, maxSize: CGSize = ImageProcessor.maxImageSize) {
        var imageRect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
        guard let cgImage = nsImage.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else {
            self.init(NSImage().cgImage(forProposedRect: &imageRect, context: nil, hints: nil)!, maxSize: maxSize)
            return
        }
        self.init(cgImage, maxSize: maxSize)
    }
}
#endif