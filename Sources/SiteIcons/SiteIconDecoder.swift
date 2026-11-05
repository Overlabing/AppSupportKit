import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

/// Turns the bytes of an icon into one small image, decoded at once so that drawing it decodes nothing.
///
/// The format is read from the first bytes, never guessed by the system. Raster formats are recognized by their
/// signature, then confirmed by ImageIO: PNG, ICO, JPEG, GIF, WebP. The rest of ImageIO (TIFF, PDF, RAW, HEIF, PSD…)
/// never serves an icon and would widen the decoder's surface. A multi-image `.ico` gives its largest image. An SVG is an
/// XML document whose root element is `svg`, made only of static elements and attributes (`SVGSafety`): nothing runs,
/// nothing is fetched. It is drawn by the system's static renderer, never a web view, and refused unless that renderer
/// read it as an SVG. Where the platform has no static SVG renderer, an SVG decodes to nil and the next candidate is
/// tried.
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
        let image: CGImage?
        if let type = rasterType(data) {
            image = raster(data, type: type, maxPixelSize: maxPixelSize)
        } else if SVGSafety.isSVGDocument(data) {
            image = svg(data, maxPixelSize: maxPixelSize)
        } else {
            return nil
        }
        guard let image, let maskColor else { return image }
        return filled(image, with: maskColor)
    }

    /// The raster type the signature at the start of `data` announces, among `rasterTypes`.
    private static func rasterType(_ data: Data) -> UTType? {
        let head = [UInt8](data.prefix(12))
        func starts(_ signature: [UInt8], at offset: Int = 0) -> Bool {
            head.count >= offset + signature.count && Array(head[offset..<offset + signature.count]) == signature
        }
        if starts([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return .png }
        if starts([0x00, 0x00, 0x01, 0x00]) { return .ico }
        if starts([0xFF, 0xD8, 0xFF]) { return .jpeg }
        if starts(Array("GIF87a".utf8)) || starts(Array("GIF89a".utf8)) { return .gif }
        if starts(Array("RIFF".utf8)), starts(Array("WEBP".utf8), at: 8) { return .webP }
        return nil
    }

    private static func raster(_ data: Data, type: UTType, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetType(source) as String? == type.identifier
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
        // NSImage picks a reader by content: only its SVG reader may have read these bytes.
        guard let image = NSImage(data: data), image.isValid,
            let svgReader = NSImageRep.class(forType: UTType.svg.identifier),
            image.representations.count == 1, image.representations.allSatisfy({ type(of: $0) == svgReader })
        else { return nil }
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

/// What makes an SVG safe to draw as an icon: one SVG document holding a static picture, read against allow-lists.
///
/// Anything the lists do not name is refused: scripts, event handlers, links, animation, filters, foreign content,
/// `<style>`, processing instructions (`<?xml-stylesheet?>`), DTDs and entities, prefixed elements (`<svg:script>`), and
/// any reference that leaves the document. The elements are SVG 2's static shapes, paths, gradients, groups, text and
/// `use`; the attributes are their geometry and the presentation attributes (SVG 2 §6.6).
enum SVGSafety {
    static let svgNamespace = "http://www.w3.org/2000/svg"
    static let xlinkNamespace = "http://www.w3.org/1999/xlink"

    static let elements: Set<String> = [
        "svg", "g", "defs", "symbol", "use", "title", "desc", "path", "rect", "circle", "ellipse", "line", "polyline",
        "polygon", "text", "tspan", "linearGradient", "radialGradient", "stop", "clipPath", "mask",
    ]

    static let attributes: Set<String> = [
        "id", "class", "lang", "xml:lang", "xml:space", "style", "version", "baseProfile",
        "x", "y", "x1", "y1", "x2", "y2", "cx", "cy", "r", "rx", "ry", "fx", "fy", "fr", "width", "height", "d", "points",
        "pathLength", "transform", "viewBox", "preserveAspectRatio", "offset", "gradientUnits", "gradientTransform",
        "spreadMethod", "clipPathUnits", "maskUnits", "maskContentUnits", "dx", "dy", "rotate", "textLength",
        "lengthAdjust",
        "fill", "fill-opacity", "fill-rule", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin",
        "stroke-miterlimit", "stroke-dasharray", "stroke-dashoffset", "stroke-opacity", "opacity", "clip-path",
        "clip-rule", "mask", "color", "display", "visibility", "overflow", "stop-color", "stop-opacity", "font-family",
        "font-size", "font-weight", "font-style", "font-variant", "text-anchor", "dominant-baseline",
        "alignment-baseline", "baseline-shift", "letter-spacing", "word-spacing", "text-decoration", "writing-mode",
        "direction", "vector-effect", "shape-rendering", "text-rendering", "color-interpolation", "paint-order",
        "transform-origin",
    ]

    /// Functions a value may call: colours, transforms, and `url()` of a fragment of the document itself.
    static let functions: Set<String> = [
        "url", "rgb", "rgba", "hsl", "hsla", "matrix", "translate", "scale", "rotate", "skewx", "skewy",
    ]

    /// An XML document whose root element is `svg`: after an optional byte-order mark, XML declaration, comments and
    /// white space, and nothing else (no DOCTYPE, no processing instruction).
    static func isSVGDocument(_ data: Data) -> Bool {
        var rest = Substring(String(decoding: data.prefix(SiteIconDecoder.maxSVGBytes), as: UTF8.self))
        if rest.first == "\u{FEFF}" { rest = rest.dropFirst() }
        if rest.hasPrefix("<?xml"), rest.dropFirst(5).first?.isWhitespace == true {
            guard let end = rest.range(of: "?>") else { return false }
            rest = rest[end.upperBound...]
        }
        while true {
            rest = rest.drop(while: \.isWhitespace)
            guard rest.hasPrefix("<!--") else { break }
            guard let end = rest.range(of: "-->") else { return false }
            rest = rest[end.upperBound...]
        }
        guard rest.hasPrefix("<svg"), let next = rest.dropFirst(4).first else { return false }
        return next == ">" || next == "/" || next.isWhitespace
    }

    /// The whole document parses as XML and every element and attribute is on the allow-lists.
    static func isStatic(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        let checker = Checker()
        parser.delegate = checker
        parser.shouldResolveExternalEntities = false
        return parser.parse() && checker.sawRoot
    }

    /// A value that calls only allowed functions, `url()` only on a fragment, and holds no CSS escape or at-rule.
    static func isLocal(_ value: String) -> Bool {
        let text = value.lowercased()
        guard !text.contains("\\"), !text.contains("@") else { return false }
        var rest = Substring(text)
        while let open = rest.firstIndex(of: "(") {
            let function = String(rest[..<open].reversed().prefix { $0.isLetter || $0.isNumber || $0 == "-" }.reversed())
            guard functions.contains(function) else { return false }
            if function == "url" {
                let argument = rest[rest.index(after: open)...].drop { $0.isWhitespace || $0 == "\"" || $0 == "'" }
                guard argument.hasPrefix("#") else { return false }
            }
            rest = rest[rest.index(after: open)...]
        }
        return true
    }

    private final class Checker: NSObject, XMLParserDelegate {
        var sawRoot = false

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
            attributes: [String: String] = [:]
        ) {
            let isRoot = !sawRoot
            sawRoot = true
            guard SVGSafety.elements.contains(name), !isRoot || name == "svg", !isRoot || attributes["xmlns"] == SVGSafety.svgNamespace,
                attributes.allSatisfy(SVGSafety.allows)
            else { return parser.abortParsing() }
        }

        func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
            parser.abortParsing()
        }
    }

    private static func allows(_ name: String, _ value: String) -> Bool {
        switch name {
        case "xmlns": value == svgNamespace
        case "xmlns:xlink": value == xlinkNamespace
        case "href", "xlink:href": value.hasPrefix("#")
        default: attributes.contains(name) && isLocal(value)
        }
    }
}
