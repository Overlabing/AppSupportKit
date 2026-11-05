# Changelog

## 0.1.2

### Added

- **DefaultApps**: `makeDefault` for a content type, next to the scheme one (issue #1).
  `DefaultApplicationClient.makeDefault(_:forContentType:)` and
  `DefaultApplicationCheck.makeDefault(forContentType:)` make the app the default for a `UTType` (`.html`). The live
  `WorkspaceDefaultApplications` calls `NSWorkspace.setDefaultApplication(at:toOpen:)` (macOS 12); the system asks the
  user to confirm when the type needs consent. `SimulatedDefaultApplications` handles it and gains
  `setDefault(_:forContentType:)` for a default changed elsewhere.
- **DefaultApps**: `DefaultApplicationCheck.status(forContentType:)`, the same `DefaultApplicationStatus` as for a
  scheme (another copy of the same app counts as this app). The read-only `defaultApplication(forContentType:)` already
  existed.
- **DefaultApps**: `DefaultApplicationError.contentTypesNotSupported`. The new client requirement has a default
  implementation that throws it, so a client written for 0.1.1 still compiles, and fails loudly rather than doing
  nothing when asked to change a content type.

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
