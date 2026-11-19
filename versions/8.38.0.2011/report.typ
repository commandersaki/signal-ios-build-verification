// Signal iOS 8.38 — source-to-binary verification
#set document(title: "Signal iOS 8.38: Source-to-Binary Verification", author: "commandersaki")
#set page(paper: "a4", margin: (x: 2.2cm, y: 2.2cm), numbering: "1 / 1",
  header: context { if counter(page).get().first() > 1 [
    #set text(8pt, fill: luma(110))
    Signal iOS 8.38 (2011) — source-to-binary verification #h(1fr) 20 November 2026
  ] })
#set text(font: ("Helvetica Neue", "Helvetica", "Arial"), size: 10pt, lang: "en")
#set par(justify: true, leading: 0.62em)
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => { v(0.8em); text(14pt, weight: "bold", it); v(0.3em) }
#show raw.where(block: false): box.with(fill: luma(240), inset: (x: 2.5pt, y: 0pt), outset: (y: 2.5pt), radius: 2pt)
#show raw: set text(font: ("Menlo", "Courier New"), size: 8.6pt)
#show link: set text(fill: rgb("#1a5fb4"))
#set table(stroke: 0.5pt + luma(190), inset: 5pt)
#show table: set par(justify: false)
#show table.cell.where(y: 0): set text(weight: "bold")

#let note(body, color: rgb("#1a5fb4")) = block(width: 100%, fill: color.lighten(90%), stroke: (left: 3pt + color), inset: 9pt, radius: 2pt, body)

#align(center)[
  #v(1.0cm)
  #text(20pt, weight: "bold")[Signal iOS 8.38 (build 2011)]\
  #v(0.2em)
  #text(14pt)[Source-to-binary verification of the App Store build]\
  #v(0.8em)
  #text(10pt, fill: luma(80))[Prepared by commandersaki with Claude Code · 20 November 2026]
  #v(0.5cm)
]

#note[
  *Result.* The compiled code (`__TEXT,__text`) of all 21 binaries in the App Store app is *byte-identical* to a local build of tag `8.38.0.2011` with Xcode 27.1 (27A9275). That covers Signal's five own binaries and all 16 bundled frameworks. In fact every binary is byte-identical apart from the 1–2 byte signature-size field: unlike 8.37, the UUIDs and the linker's GOT-slot order match too. The other differences are ones already explained for earlier versions: build metadata in plists, and rasterised images (the app icons and two asset renditions), which differ slightly from identical vector sources.

  Its four prebuilt native libraries (libsignal, RingRTC, WebRTC, libmobilecoin) were also accounted for: libsignal `v0.107.0`, RingRTC `v2.75.0` and WebRTC `8037e` are new pins and were rebuilt from source and match, and libmobilecoin `6.0.2` is unchanged from 8.36 and its rebuild carries over. So 8.38 is *fully reproducible from public source*. That covers not just the Signal-iOS repository but every library it bundles.
]

= Method
This is the same method as for #link("https://github.com/commandersaki/signal-ios-build-verification/blob/main/report/report.pdf")[8.35.1], which describes it in full.
+ The source is cloned at the Xcode Cloud path `/Volumes/workspace/repository`.
+ The third-party frameworks and prebuilt binaries are Swift Package Manager packages pinned with exact versions and resolved by `xcodebuild`.
+ An unsigned `xcodebuild archive` runs with the scheme's App Store Release configuration, using the exact Xcode build recorded in the shipped `Info.plist`.
+ `verify/compare_build.sh` and `verify/explain_residuals.sh` compare the result with the decrypted App Store IPA.

#table(
  columns: (auto, 1fr),
  table.header([Input], [Value]),
  [App Store app], [Signal 8.38 (2011), downloaded from the App Store (version ID `895602722`) and decrypted with #link("https://github.com/DrWhax/unfairplay")[unfairplay]. The encrypted IPA passes all 27,331 of its code-signature page hashes. Decryption changed nothing outside the FairPlay-encrypted ranges apart from the `cryptid` flag.],
  [Source], [Tag `8.38.0.2011`, commit `f449308eb`, the commit recorded in the shipped `Info.plist`. libsignal `0.107.0`, RingRTC `2.75.0` and MobileCoin-Swift `6.0.3-signal.1` at the versions the tag pins.],
  [Toolchain], [Xcode 27.1 (27A9275), matching the shipped `DTXcodeBuild`.],
)

= Results
#table(
  columns: (auto, 1fr),
  table.header([Check], [Result]),
  [`__TEXT,__text`, all 21 binaries], [Byte-identical (69.5 MB, hashed with Apple's `segedit` and `shasum`)],
  [Functions, Signal's 5 binaries], [154,456 of 154,456 match after address normalisation],
  [Strings, symbols, linked libraries], [Identical],
  [Whole binaries], [Each differs from the build in 1–2 bytes, all in the `__LINKEDIT` size (which includes the signature). `LC_UUID` and GOT slot order are identical in all 21.],
  [Plists], [38 differ, only in `BuildDetails` time, `BuildMachineOSBuild`, `CFBundleVersion` and `DTAppStoreToolsBuild`],
  [Asset catalogs], [All renditions identical except the 72 rasterised app-icon bitmaps (renamed randomly by `actool`) and two rasterised renditions in the share extension (`homescreen_ios`, `reactions-megaphone-bg`), whose vector sources are identical],
  [Loose icons], [107 of 14,400 and 176 of 23,104 pixels differ, by at most 1/255 in one channel],
  [Prebuilt native libraries], [libsignal `v0.107.0` and RingRTC `v2.75.0` rebuilt and byte-identical; WebRTC `8037e` rebuilt, `__TEXT,__text` byte-identical and the whole binary differing only in `LC_UUID`; libmobilecoin `6.0.2` unchanged from 8.36, whose rebuild carries over. See below.],
)

= Prebuilt native libraries
libsignal `v0.107.0`, RingRTC `v2.75.0` and WebRTC `8037e` are new pins for 8.38, so they were rebuilt from source with the toolchains recorded in the prebuilds and compared with them:
- libsignal `v0.107.0` was built with `verify/deps/build_libsignal.sh` (Rust 1.98.1, Xcode 16.4 at the runner's paths) and its `libsignal_ffi.a` matches the pinned `libsignal-client-ios-build-v0.107.0.xcframework.zip` byte for byte (803 of 803 members).
- RingRTC `v2.75.0` was built with `verify/deps/build_ringrtc.sh` (Rust 1.97.1, Xcode 26.2) and its `libringrtc.a` matches the pinned `ringrtc-ios-build-v2.75.0.xcframework.zip` byte for byte (579 of 579 members).
- WebRTC `8037e` was built with `verify/deps/build_webrtc.sh` (Xcode 26.1.1, as in the prebuild's `build_env.txt`). Its arm64 slice matches the pinned `WebRTC.framework` apart from 8 bytes, all inside the 16-byte `LC_UUID`. The `radr://5614542` linker marker that differed for 8.37's `8037b` does not appear this time. `__TEXT,__text` is byte-identical, with the same hash as the `WebRTC` binary in the App Store app.

libmobilecoin `6.0.2` is pinned to exactly the binary verified for 8.36, so its earlier result carries over (#link("https://github.com/commandersaki/signal-ios-build-verification/blob/main/versions/8.36.0.1981/out/deps/README.md")[8.36 deps]).

With the app's own code also byte-identical, every compiled byte in 8.38 traces back to public source: the equivalent of a source-reproducible build. Scripts: `verify/deps/`; outputs: `out/deps/`.

= Limitations
As for earlier versions:
- The public source itself is not reviewed.
- The toolchains are trusted: Apple's Xcode compilers, the Rust toolchains from rustup and Chromium's prebuilt clang. A compromised compiler would reproduce its own output.
- The causes of the UUID and icon-rasterisation differences are inferred, not proven.

= Reproducing
```sh
git clone https://github.com/signalapp/Signal-iOS.git /Volumes/workspace/repository
cd /Volumes/workspace/repository && git checkout 8.38.0.2011
# xcodebuild archive with Xcode 27.1 (27A9275), then:
verify/compare_build.sh signal-ios-8.38.0-2011.decrypted.ipa <built Signal.app> versions/8.38.0.2011/out/ipa_vs_build
verify/explain_residuals.sh signal-ios-8.38.0-2011.decrypted.ipa <built Signal.app> versions/8.38.0.2011/out/residuals
```
The decrypted IPA is attached to the #link("https://github.com/commandersaki/signal-ios-build-verification/releases/tag/signal-8.38.0.2011")[`signal-8.38.0.2011` release], and all outputs are in `versions/8.38.0.2011/out/`.

= Changelog
#table(
  columns: (auto, 1fr),
  table.header([Date], [Change]),
  [20 November 2026], [First published version.],
)
