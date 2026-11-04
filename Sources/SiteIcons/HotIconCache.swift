import CoreGraphics

/// Decoded icons kept in memory, read synchronously while rows are built: first in, first out, bounded in decoded
/// bytes (`bytesPerRow × height`).
public struct HotIconCache: Sendable {
    public let byteLimit: Int
    public private(set) var images: [String: CGImage] = [:]
    private var order: [String] = []
    public private(set) var bytes = 0

    public init(byteLimit: Int) {
        self.byteLimit = byteLimit
    }

    public static func cost(of image: CGImage) -> Int { image.bytesPerRow * image.height }

    public mutating func insert(_ image: CGImage, for key: String) {
        if let replaced = images.updateValue(image, forKey: key) {
            bytes -= Self.cost(of: replaced)
        } else {
            order.append(key)
        }
        bytes += Self.cost(of: image)
        // The last icon stays, even alone above the limit.
        while bytes > byteLimit, order.count > 1, let oldest = order.first {
            order.removeFirst()
            if let evicted = images.removeValue(forKey: oldest) { bytes -= Self.cost(of: evicted) }
        }
    }
}
