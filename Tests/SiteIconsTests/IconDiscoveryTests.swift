import Foundation
import SiteIcons
import Testing

/// Reading the links and the manifests, on fixtures.
@Suite struct IconDiscoveryTests {
    private let page = URL(string: "https://www.exemple.fr/accueil/")!

    @Test func linksAreResolvedSortedAndFilteredToTheSite() {
        let html = """
            <html><head>
            <LINK rel="icon" href="/favicon-16.png" sizes="16x16">
            <link rel='shortcut icon' href=favicon.ico>
            <link href="https://static.exemple.fr/icon-64.png" rel="icon" sizes="32x32 64x64">
            <link rel="apple-touch-icon" href="/touch-120.png" sizes="120x120">
            <link rel="apple-touch-icon-precomposed" href="/touch-180.png?v=2&amp;x=1" sizes="180x180">
            <link rel="icon" href="https://cdn.tiers.com/icon.png" sizes="512x512">
            <link rel="icon" href="http://www.exemple.fr/clair.png" sizes="512x512">
            <link rel="manifest" href="/site.webmanifest">
            <link rel="stylesheet" href="/style.css">
            </head></html>
            """
        let links = IconDiscovery.links(inHTML: html, page: page, site: "exemple.fr")
        #expect(links.manifest?.absoluteString == "https://www.exemple.fr/site.webmanifest")
        #expect(links.touchIcons.map(\.absoluteString) == [
            "https://www.exemple.fr/touch-180.png?v=2&x=1", "https://www.exemple.fr/touch-120.png",
        ])
        // A third-party CDN and `http` are dropped; sizes descending, no size last.
        #expect(links.icons.map(\.absoluteString) == [
            "https://static.exemple.fr/icon-64.png", "https://www.exemple.fr/favicon-16.png",
            "https://www.exemple.fr/accueil/favicon.ico",
        ])
    }

    @Test func aPageWithoutLinksGivesNothing() {
        let links = IconDiscovery.links(inHTML: "<html><head><title>x</title></head></html>", page: page, site: "exemple.fr")
        #expect(links == IconPageLinks())
    }

    @Test func manifestIconsPreferAnyThenMaskableLargestFirst() throws {
        let manifest = URL(string: "https://www.exemple.fr/assets/site.webmanifest")!
        let json = """
            {"name": "Exemple", "icons": [
              {"src": "icon-192.png", "sizes": "192x192", "type": "image/png"},
              {"src": "/mask-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"},
              {"src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable"},
              {"src": "mono.png", "sizes": "512x512", "purpose": "monochrome"},
              {"src": "icon.svg", "sizes": "any", "type": "image/svg+xml"},
              {"src": "data.json", "type": "application/json"},
              {"src": "https://cdn.tiers.com/icon.png", "sizes": "1024x1024"}
            ]}
            """
        let icons = IconDiscovery.manifestIcons(Data(json.utf8), manifest: manifest, site: "exemple.fr")
        #expect(icons.map(\.absoluteString) == [
            "https://www.exemple.fr/assets/icon.svg", "https://www.exemple.fr/assets/icon-512.png",
            "https://www.exemple.fr/assets/icon-192.png", "https://www.exemple.fr/mask-512.png",
        ])
    }

    @Test func anInvalidManifestGivesNothing() {
        let manifest = URL(string: "https://exemple.fr/m.json")!
        #expect(IconDiscovery.manifestIcons(Data("{pas du json".utf8), manifest: manifest, site: "exemple.fr").isEmpty)
        #expect(IconDiscovery.manifestIcons(Data(#"{"icons": "non"}"#.utf8), manifest: manifest, site: "exemple.fr").isEmpty)
    }

    @Test func sizesAndSiteRules() {
        #expect(IconDiscovery.largestSize("16x16 32x32") == 32)
        #expect(IconDiscovery.largestSize("any") == Int.max)
        #expect(IconDiscovery.largestSize(nil) == 0)
        #expect(IconDiscovery.largestSize("grand") == 0)
        #expect(IconDiscovery.isAllowed(URL(string: "https://exemple.fr/a.png")!, site: "exemple.fr"))
        #expect(IconDiscovery.isAllowed(URL(string: "https://img.www.exemple.fr/a.png")!, site: "exemple.fr"))
        #expect(!IconDiscovery.isAllowed(URL(string: "https://faux-exemple.fr/a.png")!, site: "exemple.fr"))
        #expect(!IconDiscovery.isAllowed(URL(string: "http://exemple.fr/a.png")!, site: "exemple.fr"))
    }
}

/// The web-standard fixes, one test each.
@Suite struct IconWebComplianceTests {
    private let page = URL(string: "https://www.exemple.fr/accueil/")!

    /// HTML §4.2.3 and §2.4.3: relative URLs resolve against the first `<base href>`, not the page.
    @Test func aBaseElementMovesRelativeLinks() {
        let html = #"<head><base href="/static/v2/"><base href="/ignored/"><link rel=icon href="favicon.png"></head>"#
        #expect(IconDiscovery.links(inHTML: html, page: page, site: "exemple.fr").icons.map(\.absoluteString) == [
            "https://www.exemple.fr/static/v2/favicon.png",
        ])
    }

    /// The tokenizer's attribute rules: any order, any quoting, `>` inside a quoted value, a repeated attribute keeps
    /// its first value, names in any case, `rel` tokens in any case and separated by any white space.
    @Test func attributesAreReadAsTheTokenizerReadsThem() {
        let html = """
            <link HREF='/a.png' REL="ICON\tShortcut" title="a > b">
            <link href=/b.png rel=icon href=/ignored.png sizes=48x48>
            <link
              rel="apple-touch-icon"
              href="/t.png"
            />
            """
        let links = IconDiscovery.links(inHTML: html, page: page, site: "exemple.fr")
        #expect(links.icons.map(\.path) == ["/b.png", "/a.png"])
        #expect(links.touchIcons.map(\.path) == ["/t.png"])
    }

    /// Markup inside comments, scripts, styles and templates is not a tag.
    @Test func quotedMarkupIsNotATag() {
        let html = """
            <!-- <link rel="icon" href="/comment.png"> -->
            <script>document.write('<link rel="icon" href="/script.png">')</script>
            <style>/* <link rel="icon" href="/style.png"> */</style>
            <template><link rel="icon" href="/template.png"></template>
            <link rel="icon" href="/real.png">
            """
        #expect(IconDiscovery.links(inHTML: html, page: page, site: "exemple.fr").icons.map(\.path) == ["/real.png"])
    }

    /// Character references decode in values: named, decimal and hexadecimal.
    @Test func characterReferencesAreDecoded() {
        let html = #"<link rel="icon" href="/i.png?a=1&amp;b=2&#38;c=3&#x26;d=4&unknown;">"#
        #expect(IconDiscovery.links(inHTML: html, page: page, site: "exemple.fr").icons.first?.absoluteString
            == "https://www.exemple.fr/i.png?a=1&b=2&c=3&d=4&unknown;")
    }

    /// HTML §4.6.8.9: an icon whose declared type the decoder cannot read is not fetched; parameters are ignored.
    @Test func anUnsupportedTypeIsSkipped() {
        let html = """
            <link rel="icon" href="/a.avif" type="image/avif" sizes="512x512">
            <link rel="icon" href="/b.svg" type="image/svg+xml" sizes="any">
            <link rel="icon" href="/c.png" type="image/png; charset=binary">
            """
        #expect(IconDiscovery.links(inHTML: html, page: page, site: "exemple.fr").icons.map(\.path) == ["/b.svg", "/c.png"])
    }

    /// `sizes="any"` (a scalable icon) ranks before every size; several sizes count by the largest.
    @Test func anyAndSeveralSizesRank() {
        let html = """
            <link rel="icon" href="/48.png" sizes="16x16 48x48">
            <link rel="icon" href="/v.svg" sizes="any">
            <link rel="icon" href="/32.png" sizes="32x32">
            """
        #expect(IconDiscovery.links(inHTML: html, page: page, site: "exemple.fr").icons.map(\.path) == ["/v.svg", "/48.png", "/32.png"])
    }

    /// RFC 2397: a `data:` icon is kept (it needs no request); a `data:` URL that is not an image is not.
    @Test func dataIconsAreKept() throws {
        let png = try iconPNG(size: 8).base64EncodedString()
        let html = """
            <link rel="icon" href="data:image/png;base64,\(png)">
            <link rel="icon" href="data:text/html,<p>no</p>">
            """
        let icons = IconDiscovery.links(inHTML: html, page: page, site: "exemple.fr").icons
        #expect(icons.count == 1)
        let decoded = try #require(DataURL(icons[0]))
        #expect(decoded.mediaType == "image/png")
        #expect(decoded.data == (try iconPNG(size: 8)))
        #expect(DataURL(URL(string: "data:,Hello%20world")!)?.data == Data("Hello world".utf8))
        #expect(DataURL(URL(string: "data:image/png;base64,AAAA")!, limit: 2) == nil)
        #expect(DataURL(URL(string: "https://exemple.fr/a.png")!) == nil)
    }

    /// `mask-icon` (HTML §4.2.4, the `color` attribute): kept with its colour, tried last, after the default paths.
    @Test func maskIconsComeLastWithTheirColour() {
        let html = """
            <link rel="mask-icon" href="/pin.svg" color="#5BBAD5">
            <link rel="icon" href="/f.png">
            """
        let links = IconDiscovery.links(inHTML: html, page: page, site: "exemple.fr")
        #expect(links.maskIcons == [IconCandidate(url: URL(string: "https://www.exemple.fr/pin.svg")!, maskColor: "#5bbad5")])
        let order = IconDiscovery.candidates(links, origin: "exemple.fr", limit: 8)
        #expect(order.map(\.url.absoluteString) == [
            "https://www.exemple.fr/f.png", "https://exemple.fr/apple-touch-icon.png", "https://exemple.fr/favicon.ico",
            "https://www.exemple.fr/pin.svg",
        ])
        #expect(order.last?.maskColor == "#5bbad5")
        #expect(IconDiscovery.candidates(links, origin: "exemple.fr", limit: 2).count == 2)
    }

    /// Web App Manifest §1.7 and §2.5: `src` resolves against the manifest URL; the manifest URL itself against the
    /// document base URL; a `type` with parameters still counts.
    @Test func theManifestResolvesAgainstItsOwnURL() {
        let html = #"<base href="https://cdn.exemple.fr/app/"><link rel="manifest" href="m/site.webmanifest">"#
        let links = IconDiscovery.links(inHTML: html, page: page, site: "exemple.fr")
        let manifest = try! #require(links.manifest)
        #expect(manifest.absoluteString == "https://cdn.exemple.fr/app/m/site.webmanifest")
        let json = #"{"icons": [{"src": "../i.png", "type": "image/png; q=1", "purpose": "any monochrome"}]}"#
        #expect(IconDiscovery.manifestIcons(Data(json.utf8), manifest: manifest, site: "exemple.fr").map(\.absoluteString) == [
            "https://cdn.exemple.fr/app/i.png",
        ])
    }

    /// Links an app read from a loaded page go through the same rules.
    @Test func tagsReadFromALoadedPageAreRankedTheSameWay() {
        let tags: [[String: String]] = [["rel": "icon", "href": "/16.png", "sizes": "16x16"], ["rel": "icon", "href": "/64.png", "sizes": "64x64"]]
        #expect(IconDiscovery.links(fromTags: tags, base: page, site: "exemple.fr").icons.map(\.path) == ["/64.png", "/16.png"])
    }
}
