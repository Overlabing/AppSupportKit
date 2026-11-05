import CoreGraphics
import Foundation
import SiteIcons
import Testing
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

@Suite struct SiteIconDecoderTests {
    @Test("A type outside the allow-list (TIFF) is not decoded; PNG is")
    func onlyAllowedRasterTypes() throws {
        let tiff = try encoded(iconImage(size: 32), as: .tiff)
        #expect(SiteIconDecoder.decode(tiff, maxPixelSize: 96) == nil)
        #expect(SiteIconDecoder.decode(try iconPNG(size: 32), maxPixelSize: 96)?.width == 32)
        #expect(SiteIconDecoder.decode(try iconPNG(size: 512), maxPixelSize: 96)?.width == 96)
        #expect(SiteIconDecoder.decode(Data("not an image".utf8), maxPixelSize: 96) == nil)
    }

    @Test("A multi-image .ico gives its largest image, whatever its place")
    func aMultiImageICOGivesItsLargest() throws {
        #expect(SiteIconDecoder.decode(try iconICO(sizes: [16, 64, 32]), maxPixelSize: 96)?.width == 64)
        #expect(SiteIconDecoder.decode(try iconICO(sizes: [16, 48]), maxPixelSize: 32)?.width == 32)
    }

    @Test("A PDF or a TIFF carrying <svg in its first bytes is refused")
    func anotherFormatPosingAsSVGIsRefused() throws {
        for data in [try pdfCarryingSVGTag(size: 16), try tiffCarryingSVGTag(size: 2)] {
            #expect(String(decoding: data.prefix(1024), as: UTF8.self).contains("<svg"))
            #if canImport(AppKit)
            // The system would draw both: only the decoder's own checks refuse them.
            #expect(NSImage(data: data)?.isValid == true)
            #endif
            #expect(SiteIconDecoder.decode(data, maxPixelSize: 96) == nil)
        }
    }

    #if os(macOS)
    private let square = ##"<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="#ff0000"/></svg>"##

    @Test("A static SVG is drawn at the requested size")
    func aStaticSVGIsDrawn() throws {
        let image = try #require(SiteIconDecoder.decode(Data(square.utf8), maxPixelSize: 96))
        #expect(image.width == 96 && image.height == 96)
        #expect(try centrePixel(image) == [255, 0, 0, 255])
        let viewBoxOnly = ##"<?xml version="1.0"?><!-- logo --><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 20"><rect width="10" height="20"/></svg>"##
        let tall = try #require(SiteIconDecoder.decode(Data(viewBoxOnly.utf8), maxPixelSize: 96))
        #expect(tall.height == 96)
    }

    @Test("An SVG that could run something or fetch something, or is not one SVG document, is refused", arguments: [
        ##"<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script><rect width="9" height="9"/></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"><rect width="9" height="9"/></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><image href="https://tracker.example/p.png" width="9" height="9"/></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><rect width="9" height="9" fill="url(https://e.example/x.svg#p)"/></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><a xlink:href="https://e.example"><rect width="9" height="9"/></a></svg>"##,
        ##"<!DOCTYPE svg [<!ENTITY a "aaaa">]><svg xmlns="http://www.w3.org/2000/svg"><text>&a;</text></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><foreignObject><p>x</p></foreignObject></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><style>@import url(https://e.example/s.css);</style></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><svg:script xmlns:svg="http://www.w3.org/2000/svg">alert(1)</svg:script><rect width="9" height="9"/></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><svg:foreignObject xmlns:svg="http://www.w3.org/2000/svg" width="9" height="9"><p>x</p></svg:foreignObject></svg>"##,
        ##"<?xml-stylesheet href="https://e.example/s.css"?><svg xmlns="http://www.w3.org/2000/svg"><rect width="9" height="9"/></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><rect width="9" height="9"/><?xml-stylesheet href="https://e.example/s.css"?></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><use xlink:href="https://e.example/s.svg#a"/></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg" xmlns:x="http://www.w3.org/1999/xlink"><use x:href="https://e.example/s.svg#a"/></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><a href="#r"><rect id="r" width="9" height="9"/></a></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><rect width="9" height="9"><set attributeName="fill" to="url(https://e.example/p.svg#p)"/></rect></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><rect width="9" height="9" style="fill: url( 'https://e.example/p.svg#p' )"/></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><g xmlns="http://www.w3.org/1999/xhtml"><rect width="9" height="9"/></g></svg>"##,
        ##"<svg xmlns="http://www.w3.org/1999/xhtml"><rect width="9" height="9"/></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><rect width="9" height="9" filter="url(#f)"/><filter id="f"><feImage href="#r"/></filter></svg>"##,
        ##"<svg xmlns="http://www.w3.org/2000/svg"><rect width="9" height="9"/>"##,
        ##"<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg"><rect width="9" height="9"/></svg>"##,
        ##"<html><svg xmlns="http://www.w3.org/2000/svg"><rect width="9" height="9"/></svg></html>"##,
    ])
    func anActiveSVGIsRefused(svg: String) {
        #expect(SiteIconDecoder.decode(Data(svg.utf8), maxPixelSize: 96) == nil)
    }

    @Test("A gradient referenced inside the document is still static")
    func anInternalReferenceIsAllowed() {
        let svg = ##"<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><defs><linearGradient id="g"><stop offset="0" stop-color="#00f"/></linearGradient></defs><rect width="8" height="8" fill="url(#g)"/></svg>"##
        #expect(SiteIconDecoder.decode(Data(svg.utf8), maxPixelSize: 16) != nil)
    }

    @Test("A static icon as exporters write it is drawn: comments, style attribute, text, clip path, local use")
    func anExportedStaticSVGIsDrawn() throws {
        let svg = ##"""
            \##u{FEFF}<?xml version="1.0" encoding="UTF-8" standalone="no"?>
            <!-- Exported -->
            <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" viewBox="0 0 32 32" width="32" height="32">
              <title>Logo</title>
              <defs>
                <radialGradient id="g" cx="50%" cy="50%" r="50%"><stop offset="0" style="stop-color:#00ff00"/></radialGradient>
                <clipPath id="c"><circle cx="16" cy="16" r="16"/></clipPath>
                <path id="p" d="M0 0h32v32h-32z"/>
              </defs>
              <g clip-path="url(#c)" fill-rule="evenodd">
                <use xlink:href="#p" style="fill: url(#g); opacity: 1"/>
                <use href="#p" fill="#00ff00"/>
              </g>
              <text x="2" y="30" font-family="Helvetica" font-size="4"><tspan>a</tspan></text>
            </svg>
            """##
        let image = try #require(SiteIconDecoder.decode(Data(svg.utf8), maxPixelSize: 64))
        #expect(image.width == 64)
        #expect(try centrePixel(image) == [0, 255, 0, 255])
    }

    @Test("An SVG over the size limit is refused")
    func aHugeSVGIsRefused() {
        let padding = String(repeating: " ", count: SiteIconDecoder.maxSVGBytes)
        #expect(SiteIconDecoder.decode(Data((square + padding).utf8), maxPixelSize: 96) == nil)
    }

    @Test("A mask icon is filled with its colour")
    func aMaskIconIsFilled() throws {
        let black = ##"<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16"/></svg>"##
        let image = try #require(SiteIconDecoder.decode(Data(black.utf8), maxPixelSize: 32, maskColor: "#0080ff"))
        #expect(try centrePixel(image) == [0, 128, 255, 255])
    }
    #endif
}

@Suite("The hot cache of icons, bounded in bytes")
struct HotIconCacheTests {
    @Test("Past the limit the oldest go and the total stays under it")
    func evictsOldestPastLimit() throws {
        let icon = try iconImage(size: 96)
        let cost = HotIconCache.cost(of: icon)
        var cache = HotIconCache(byteLimit: cost * 3)
        for key in ["a", "b", "c", "d"] { cache.insert(icon, for: key) }
        #expect(cache.images["a"] == nil)
        #expect(Set(cache.images.keys) == ["b", "c", "d"])
        #expect(cache.bytes == cost * 3)
    }

    @Test("Replacing an icon does not count it twice")
    func replacementKeepsCost() throws {
        let small = try iconImage(size: 32), large = try iconImage(size: 96)
        var cache = HotIconCache(byteLimit: 10 * HotIconCache.cost(of: large))
        cache.insert(small, for: "a")
        cache.insert(large, for: "a")
        #expect(cache.bytes == HotIconCache.cost(of: large))
        #expect(cache.images.count == 1)
    }

    @Test("A single icon heavier than the limit stays")
    func lastIconStays() throws {
        var cache = HotIconCache(byteLimit: 1)
        cache.insert(try iconImage(size: 96), for: "a")
        #expect(cache.images["a"] != nil)
    }
}
