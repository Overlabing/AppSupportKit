# AppSupportKit

Non-UI building blocks shared by Overlabing's Mac and iOS apps. A Swift package for macOS 26 and iOS 26, Swift 6 with
strict concurrency, no third-party dependency. MIT licensed.

The kit never names an app. Storage keys, environment variable names, cache keys, log subsystems and every user-facing
text an app owns are passed in. The kit's own strings use English keys, with French in its String Catalogs.

| Product | What it holds |
|---|---|
| `Localization` | `localized(_:bundle:pinnedTo:)`, and `PinnedLanguage.read(_:)`, which pins a test run's language through a variable the caller names |
| `Preferences` | `KeyValueStore` (with `UserDefaults` and `InMemoryKeyValueStore`), `Preference<Value>` (JSON under the app's key), `SettingsModel<Value>` (`update`, `replace`, `takeLoadError`), `FlagPreference` (a switch a Debug variable can force on), and `DefaultEntry`, one entry of an app's registry of defaults |
| `UserFacing` | `UserFacingError`: title, message, technical detail, one `Action` (retry, open a URL, open a settings pane, custom), `Presentation` (banner or alert), `isCancellation(_:)` |
| `DefaultApps` | `DefaultApplicationClient` (scheme or content type → installed app, open it, make an app the default), `DefaultApplicationCheck` and `DefaultApplicationStatus`, `WorkspaceDefaultApplications` (macOS) and `SimulatedDefaultApplications` |
| `Spaces` | `SpaceGlyph` (initial, SF Symbol or emoji), `SpaceIconCatalog`, `SpaceRules` (`validateName`, `moved`, `neighbor`, `deletionDestinations`), `SpaceDeletionChoices`, `SpaceSwitching` (`choices`, `matching`, `target`, `visible`, `selected`), `LaunchSpace` and `StoredSpace` |
| `SiteIcons` | Finding a site's icons in a document the app already has, ranking them, decoding them safely, and caching them on disk under a key the app gives |

## Using it

```swift
.package(url: "https://github.com/Overlabing/AppSupportKit", exact: "0.1.0"),
```

Each module that has strings keeps a one-line wrapper, because `Bundle.module` belongs to each target:

```swift
import Localization

func localized(_ value: String.LocalizationValue) -> String {
    Localization.localized(value, bundle: .module, pinnedTo: PinnedLanguage.read("MYAPP_TEST_LANGUAGE"))
}
```

The kit's own strings follow `OVERLABING_TEST_LANGUAGE`. An app whose tests assert the kit's sentences sets it next to
its own variable.

## SiteIcons

The kit never fetches anything and never computes a cache key. The app brings:

1. **The source.** Fetch a page and pass its HTML to `IconDiscovery.links(inHTML:page:site:)`, or pass the `<link>`
   attributes it read from a loaded page to `IconDiscovery.links(fromTags:base:site:)`. Fetch the manifest if it wants its
   icons (`IconDiscovery.manifestIcons`), then each candidate in `IconDiscovery.candidates` order. A `data:` candidate
   needs no request (`DataURL`).
2. **The cache key**, given to `SiteIconCache` and `HotIconCache`: a registrable domain, a page origin, anything.
3. **The policy**: when fetching is allowed at all, and how long an icon lives (`IconLifetime`).

The standards it follows:

- WHATWG HTML: §4.2.3 the `base` element and §2.4.3 document base URLs; §4.2.4 the `link` element (`rel` is an unordered
  set of unique space-separated tokens; the `color` attribute of `mask-icon`); §4.6.8.9 link type `icon` (`sizes`,
  `any`, an unsupported `type` is not fetched); §4.6.8.11 link type `manifest`; the tokenizer's attribute rules (any
  order, double, single or no quotes, first of a repeated attribute kept, character references decoded), without
  regular expressions.
- W3C Web App Manifest: §1.7 the `icons` member, `src` resolved against the manifest URL (§2.5, processing image
  resources), the `purpose` member (`any`, `maskable`, `monochrome`); W3C Image Resource §4.1–§4.3 (`src`, `sizes`,
  `type`).
- RFC 2397, the `data:` URL scheme.
- RFC 9111: §5.2.2.1 `max-age`, §5.2.2.4 `no-cache`, §5.2.2.5 `no-store`, §4.2.2 heuristic freshness.

Decoding accepts PNG, ICO (its largest image), JPEG, GIF and WebP, recognized by their signature before decoding, and
at most 4096 × 4096 pixels. An SVG must be an XML document whose root element is `svg`, with no DTD and no processing
instruction, made only of allow-listed static elements (shapes, paths, gradients, groups, text, `use` of a local
fragment) and presentation attributes. The system's static renderer (macOS) draws it, and the result is kept only when
that renderer read it as an SVG. Elsewhere an SVG decodes to nil and the next candidate is tried.

## Developing

`./check.sh` runs the tests with French then English pinned, builds for the iOS simulator, and runs AppTooling's leak
scan over the tree and the whole history. It fetches AppTooling at the version pinned in `scripts/apptooling.pin`.
CI runs the same script.

Releases are annotated tags `vX.Y.Z`, never moved. Consumers pin `exact:`.
