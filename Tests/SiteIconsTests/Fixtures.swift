import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// A plain square image of `size` pixels.
func iconImage(size: Int, red: CGFloat = 0.2) throws -> CGImage {
    let context = try #require(CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(red: red, green: 0.4, blue: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    return try #require(context.makeImage())
}

/// A plain square PNG of `size` pixels.
func iconPNG(size: Int) throws -> Data {
    try encoded(iconImage(size: size), as: .png)
}

func encoded(_ image: CGImage, as type: UTType) throws -> Data {
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

/// An `.ico` holding one PNG per size, in the order given.
func iconICO(sizes: [Int]) throws -> Data {
    let images = try sizes.map(iconPNG(size:))
    var data = Data([0, 0, 1, 0, UInt8(sizes.count), 0])
    var offset = 6 + 16 * sizes.count
    func little(_ value: Int, _ bytes: Int) -> [UInt8] { (0..<bytes).map { UInt8((value >> (8 * $0)) & 0xFF) } }
    for (size, image) in zip(sizes, images) {
        let side = UInt8(size >= 256 ? 0 : size)
        data += [side, side, 0, 0] + little(1, 2) + little(32, 2) + little(image.count, 4) + little(offset, 4)
        offset += image.count
    }
    for image in images { data += image }
    return data
}

/// The colour of the image's centre pixel, 0…255 per channel.
func centrePixel(_ image: CGImage) throws -> [UInt8] {
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = try #require(CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: CGRect(x: -image.width / 2, y: -image.height / 2, width: image.width, height: image.height))
    return pixel
}

/// A one-page PDF of `size` points with `<svg>` in a comment line right after its header, where a check of the first
/// bytes for `<svg` would find it.
func pdfCarryingSVGTag(size: Int) throws -> Data {
    let pdf = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: size, height: size)
    let consumer = try #require(CGDataConsumer(data: pdf))
    let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
    context.beginPDFPage(nil)
    context.fill(box)
    context.endPDFPage()
    context.closePDF()
    var data = pdf as Data
    let header = try #require(data.firstIndex(of: UInt8(ascii: "\n")))
    data.insert(contentsOf: Data("%<svg>\n".utf8), at: header + 1)
    return data
}

/// A TIFF of `size` pixels whose description, early in the file, reads `<svg …>`.
func tiffCarryingSVGTag(size: Int) throws -> Data {
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.tiff.identifier as CFString, 1, nil))
    let properties = [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFImageDescription: "<svg xmlns=\"http://www.w3.org/2000/svg\">"]]
    CGImageDestinationAddImage(destination, try iconImage(size: size), properties as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}
