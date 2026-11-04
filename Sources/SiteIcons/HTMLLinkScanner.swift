/// Reads the `<link>` and `<base>` start tags of an HTML document the way the HTML tokenizer reads attributes (WHATWG
/// HTML, "Parsing HTML documents", tokenization), without regular expressions and without building a DOM: attributes in any order, with
/// double, single or no quotes, names lowercased, the first of a repeated attribute kept, character references decoded.
/// Comments, doctypes and end tags are skipped, and so is the text of `script`, `style`, `template` and the other
/// raw-text or escapable-text elements, so that markup quoted there is never read as a tag.
enum HTMLLinkScanner {
    struct Tags: Equatable {
        /// The `href` of the first `<base>` that has one (HTML §4.2.3, the base element).
        var baseHref: String?
        /// Every `<link>`, in document order.
        var links: [[String: String]] = []
    }

    private static let rawTextElements: Set<String> = [
        "script", "style", "template", "textarea", "title", "xmp", "iframe", "noembed", "noframes",
    ]

    static func scan(_ html: String) -> Tags {
        let bytes = Array(html.utf8)
        var tags = Tags()
        var index = 0
        while let open = bytes[index...].firstIndex(of: UInt8(ascii: "<")) {
            index = open + 1
            guard index < bytes.count else { break }
            if bytes.hasPrefix("!--", at: index) {
                index = bytes.index(after: "-->", from: index + 3) ?? bytes.count
            } else if bytes[index] == UInt8(ascii: "!") || bytes[index] == UInt8(ascii: "?") || bytes[index] == UInt8(ascii: "/") {
                index = (bytes[index...].firstIndex(of: UInt8(ascii: ">")) ?? bytes.count - 1) + 1
            } else if bytes[index].isASCIILetter {
                let (name, list, end) = startTag(bytes, from: index)
                index = end
                // A repeated attribute is a parse error and the tokenizer keeps the first one.
                let attributes = Dictionary(list.map { ($0.name, $0.value) }, uniquingKeysWith: { first, _ in first })
                if name == "link" {
                    tags.links.append(attributes)
                } else if name == "base", tags.baseHref == nil, let href = attributes["href"] {
                    tags.baseHref = href
                } else if rawTextElements.contains(name) {
                    index = bytes.index(afterEndTag: name, from: index) ?? bytes.count
                }
            }
        }
        return tags
    }

    /// Every attribute of every start tag of `markup`, in order: what an SVG declares, for `SVGSafety`.
    static func allAttributes(in markup: String) -> [(name: String, value: String)] {
        let bytes = Array(markup.utf8)
        var found: [(name: String, value: String)] = []
        var index = 0
        while let open = bytes[index...].firstIndex(of: UInt8(ascii: "<")) {
            index = open + 1
            guard index < bytes.count else { break }
            if bytes[index].isASCIILetter {
                let (_, attributes, end) = startTag(bytes, from: index)
                found += attributes
                index = end
            }
        }
        return found
    }

    /// The tag name, its attributes and the index just past its `>`.
    private static func startTag(_ bytes: [UInt8], from start: Int) -> (String, [(name: String, value: String)], Int) {
        var index = start
        while index < bytes.count, !bytes[index].isHTMLSpace, bytes[index] != UInt8(ascii: "/"), bytes[index] != UInt8(ascii: ">") {
            index += 1
        }
        let name = String(decoding: bytes[start..<index], as: UTF8.self).lowercased()
        var attributes: [(name: String, value: String)] = []
        while index < bytes.count {
            while index < bytes.count, bytes[index].isHTMLSpace || bytes[index] == UInt8(ascii: "/") { index += 1 }
            guard index < bytes.count, bytes[index] != UInt8(ascii: ">") else { break }
            let nameStart = index
            index += 1
            while index < bytes.count, !bytes[index].isHTMLSpace, ![UInt8(ascii: "/"), UInt8(ascii: ">"), UInt8(ascii: "=")].contains(bytes[index]) {
                index += 1
            }
            let attribute = String(decoding: bytes[nameStart..<index], as: UTF8.self).lowercased()
            while index < bytes.count, bytes[index].isHTMLSpace { index += 1 }
            var value = ""
            if index < bytes.count, bytes[index] == UInt8(ascii: "=") {
                index += 1
                while index < bytes.count, bytes[index].isHTMLSpace { index += 1 }
                if index < bytes.count, bytes[index] == UInt8(ascii: "\"") || bytes[index] == UInt8(ascii: "'") {
                    let quote = bytes[index]
                    let valueStart = index + 1
                    index = bytes[valueStart...].firstIndex(of: quote) ?? bytes.count
                    value = String(decoding: bytes[valueStart..<index], as: UTF8.self)
                    index = min(index + 1, bytes.count)
                } else {
                    let valueStart = index
                    while index < bytes.count, !bytes[index].isHTMLSpace, bytes[index] != UInt8(ascii: ">") { index += 1 }
                    value = String(decoding: bytes[valueStart..<index], as: UTF8.self)
                }
            }
            attributes.append((attribute, CharacterReferences.decode(value)))
        }
        return (name, attributes, min(index + 1, bytes.count))
    }
}

/// The character references found in attribute values: numeric ones, and the few named ones a URL or a colour uses.
enum CharacterReferences {
    private static let named: [String: String] = [
        "amp": "&", "quot": "\"", "apos": "'", "lt": "<", "gt": ">", "nbsp": "\u{A0}",
    ]

    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        var rest = Substring(text)
        while let ampersand = rest.firstIndex(of: "&") {
            result += rest[..<ampersand]
            let afterAmpersand = rest.index(after: ampersand)
            guard let semicolon = rest[afterAmpersand...].prefix(12).firstIndex(of: ";"),
                let decoded = reference(rest[afterAmpersand..<semicolon])
            else {
                result.append("&")
                rest = rest[afterAmpersand...]
                continue
            }
            result += decoded
            rest = rest[rest.index(after: semicolon)...]
        }
        return result + rest
    }

    private static func reference(_ body: Substring) -> String? {
        if body.hasPrefix("#x") || body.hasPrefix("#X") {
            return UInt32(body.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String($0) }
        }
        if body.hasPrefix("#") {
            return UInt32(body.dropFirst()).flatMap(Unicode.Scalar.init).map { String($0) }
        }
        return named[body.lowercased()]
    }
}

extension UInt8 {
    fileprivate var isHTMLSpace: Bool { self == 0x20 || self == 0x09 || self == 0x0A || self == 0x0C || self == 0x0D }
    fileprivate var isASCIILetter: Bool { (0x41...0x5A).contains(self) || (0x61...0x7A).contains(self) }
    fileprivate var lowercasedASCII: UInt8 { (0x41...0x5A).contains(self) ? self + 0x20 : self }
}

extension [UInt8] {
    fileprivate func hasPrefix(_ text: String, at index: Int) -> Bool {
        let needle = Array(text.utf8)
        guard index + needle.count <= count else { return false }
        return self[index..<index + needle.count].elementsEqual(needle)
    }

    /// The index just past the first `text` at or after `start`.
    fileprivate func index(after text: String, from start: Int) -> Int? {
        let needle = Array(text.utf8)
        var index = start
        while index + needle.count <= count {
            if self[index..<index + needle.count].elementsEqual(needle) { return index + needle.count }
            index += 1
        }
        return nil
    }

    /// The index of the `<` of `</name`, case ignored, at or after `start`.
    fileprivate func index(afterEndTag name: String, from start: Int) -> Int? {
        let needle = Array("</\(name)".utf8)
        var index = start
        while index + needle.count <= count {
            if self[index..<index + needle.count].map(\.lowercasedASCII).elementsEqual(needle) { return index }
            index += 1
        }
        return nil
    }
}
