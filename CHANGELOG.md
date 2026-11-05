# Changelog

## 0.1.1

### Fixed

- **SiteIcons**: the decoder reads the format from the first bytes. A raster is decoded only when its signature is PNG,
  ICO, JPEG, GIF or WebP and ImageIO agrees. An SVG is accepted only as an XML document whose root element is `svg`,
  and its drawing is refused unless the system read it as an SVG. Before, a PDF or a TIFF carrying `<svg` in its first
  kilobyte was decoded.
- **SiteIcons**: SVG safety is an allow-list of static elements and attributes instead of a deny-list. Prefixed
  elements (`<svg:script>`), processing instructions (`<?xml-stylesheet?>`), `<style>`, animation, filters, links and
  CSS escapes are refused; `href` and `url()` may only point inside the document.
- **SiteIcons**: `<link rel="manifest" type="application/manifest+json">` is kept. The `type` filter applies to icons,
  touch icons and mask icons only.

## 0.1.0

First release, extracted from one app so that a second can share it.

### Added

- **Localization**: the localized-string core and the pinned test language.
- **Preferences**: `KeyValueStore`, `Preference<Value>`, `SettingsModel<Value>`, `FlagPreference`, `DefaultEntry`.
- **UserFacing**: the `UserFacingError` core, its actions and presentations, and cancellation detection.
- **DefaultApps**: the LaunchServices seam for default apps, live on macOS and simulated.
- **Spaces**: Space glyphs (initial, SF Symbol, emoji), the symbol catalogue, ordering, neighbours, deletion
  destinations and choices, switching, and the Space opened at launch.
- **SiteIcons**: icon discovery in HTML and web app manifests, ranking, `data:` URLs, mask icons, hardened decoding (ICO,
  static SVG), a disk cache with negative markers and Cache-Control lifetimes, and a hot cache bounded in bytes.
