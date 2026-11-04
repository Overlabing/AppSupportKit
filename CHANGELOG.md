# Changelog

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
