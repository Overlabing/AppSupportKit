import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

/// Turns the bytes of an icon into one small image, decoded at once so that drawing it decodes nothing.
///
/// Raster formats are checked before any decoding: PNG, ICO, JPEG, GIF, WebP. The rest of ImageIO (TIFF, PDF, RAW,
/// HEIF, PSD…) never serves an icon and would widen the decoder's surface. A multi-image `.ico` gives its largest image.
/// An SVG is drawn by the system's static renderer, never a web view, and only once it holds no script, no event
/// handler, no external reference and no DTD: nothing runs, nothing is fetched (`SVGSafety`). Where the platform has
/// no static SVG renderer, an SVG decodes to nil and the next candidate is tried.
public enum SiteIconDecoder {
    /// The raster types decoded, by uniform type identifier.
    public static let rasterTypes: Set<String> = [
        UTType.png.identifier, UTType.ico.identifier, UTType.jpeg.identifier, UTType.gif.identifier,
        UTType.webP.identifier,
    ]
    /// Images of an `.ico` or a GIF looked at, at most.
    public static let maxFrames = 64
    /// An image with more pixels than this (4096 × 4096) is never decoded: no icon needs it, and a small file can
    /// declare a huge one.
    public static let maxSourcePixels = 4096 * 4096
    /// An SVG longer than this is refused.
    public static let maxSVGBytes = 256 * 1024

    /// The icon, its longer side at most `maxPixelSize` pixels; nil when the bytes are not an allowed image. A mask
    /// icon is filled with `maskColor` (`#rrggbb`).
    public static func decode(_ data: Data, maxPixelSize: Int, maskColor: String? = nil) -> CGImage? {
        let image = SVGSafety.looksLikeSVG(data) ? svg(data, maxPixelSize: maxPixelSize) : raster(data, maxPixelSize: maxPixelSize)
        guard let image, let maskColor else { return image }
        return filled(image, with: maskColor)
    }

    private static func raster(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let type = CGImageSourceGetType(source) as String?, rasterTypes.contains(type)
        else { return nil }
        let count = min(CGImageSourceGetCount(source), maxFrames)
        var best: Int?
        var bestWidth = 0
        for index in 0..<count {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
            guard width.multipliedReportingOverflow(by: height).partialValue <= maxSourcePixels, width > 0, height > 0 else {
                continue
            }
            if best == nil || width > bestWidth { best = index; bestWidth = width }
        }
        guard let best else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, best, options as CFDictionary)
    }

    private static func svg(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard data.count <= maxSVGBytes, SVGSafety.isStatic(data) else { return nil }
        #if canImport(AppKit)
        guard let image = NSImage(data: data), image.isValid else { return nil }
        let size = image.size
        let scale = size.width > 0 && size.height > 0 ? Double(maxPixelSize) / max(size.width, size.height) : 1
        let width = max(1, Int((size.width > 0 ? size.width * scale : Double(maxPixelSize)).rounded()))
        let height = max(1, Int((size.height > 0 ? size.height * scale : Double(maxPixelSize)).rounded()))
        guard let context = bitmap(width: width, height: height) else { return nil }
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
        #else
        return nil
        #endif
    }

    /// The image's shape filled with one colour, as a pinned tab draws a mask icon.
    private static func filled(_ image: CGImage, with hex: String) -> CGImage? {
        guard let color = color(hex), let context = bitmap(width: image.width, height: image.height) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.draw(image, in: rect)
        context.setBlendMode(.sourceIn)
        context.setFillColor(color)
        context.fill(rect)
        return context.makeImage()
    }

    private static func bitmap(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    private static func color(_ hex: String) -> CGColor? {
        guard let value = IconDiscovery.hexColor(hex), let rgb = UInt32(value.dropFirst(), radix: 16) else { return nil }
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CGColor(colorSpace: space, components: [
            CGFloat((rgb >> 16) & 0xFF) / 255, CGFloat((rgb >> 8) & 0xFF) / 255, CGFloat(rgb & 0xFF) / 255, 1,
        ])
    }
}

/// What makes an SVG safe to draw as an icon: a static picture. Checked on the text before any parsing.
enum SVGSafety {
    /// An SVG document, after an optional byte-order mark, XML declaration, comments and white space.
    static func looksLikeSVG(_ data: Data) -> Bool {
        let head = String(decoding: data.prefix(1024), as: UTF8.self).lowercased()
        guard let tag = head.range(of: "<svg") else { return false }
        let before = head[..<tag.lowerBound]
        return !before.contains("<html") && !before.contains("<!doctype html")
    }

    private static let refused = [
        "<script", "<foreignobject", "<!doctype", "<!entity", "<iframe", "<object", "<embed", "<use", "<image",
        "<feimage", "@import", "javascript:",
    ]

    /// No script, no event handler (`on…=`), no DTD or entity, no external resource (`href`, `src` or `url()` that is
    /// not a fragment of the document itself).
    static func isStatic(_ data: Data) -> Bool {
        let text = String(decoding: data, as: UTF8.self).lowercased()
        guard refused.allSatisfy({ !text.contains($0) }) else { return false }
        for attribute in HTMLLinkScanner.allAttributes(in: text) {
            if attribute.name.hasPrefix("on") { return false }
            if attribute.name.hasSuffix("href") || attribute.name == "src", !attribute.value.hasPrefix("#") { return false }
        }
        var rest = Substring(text)
        while let call = rest.range(of: "url(") {
            let argument = rest[call.upperBound...].drop { $0 == " " || $0 == "\"" || $0 == "'" }
            guard argument.hasPrefix("#") else { return false }
            rest = argument
        }
        return true
    }
}
