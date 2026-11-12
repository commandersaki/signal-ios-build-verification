// Signal iOS 8.37 — source-to-binary verification
#set document(title: "Signal iOS 8.37: Source-to-Binary Verification", author: "commandersaki")
#set page(paper: "a4", margin: (x: 2.2cm, y: 2.2cm), numbering: "1 / 1",
  header: context { if counter(page).get().first() > 1 [
    #set text(8pt, fill: luma(110))
    Signal iOS 8.37 (1993) — source-to-binary verification #h(1fr) 12 November 2026
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
  #text(20pt, weight: "bold")[Signal iOS 8.37 (build 1993)]\
  #v(0.2em)
  #text(14pt)[Source-to-binary verification of the App Store build]\
  #v(0.8em)
  #text(10pt, fill: luma(80))[Prepared by commandersaki with Claude Code · 12 November 2026]
  #v(0.5cm)
]

#note[
  *Result.* The compiled code (`__TEXT,__text`) of all 21 binaries in the App Store app is *byte-identical* to a local build of tag `8.37.0.1993` with Xcode 27.1 (27A9275). That covers Signal's five own binaries and all 16 bundled frameworks. Every other difference is one already explained for earlier versions: the signature-size field in every binary; the UUID and the linker's GOT-slot order in `Signal` and `SignalServiceKit`, with every stub resolving to the same target; build metadata in plists; and rasterised images (the app icons and two asset renditions), which differ slightly from identical vector sources.

  Its four prebuilt native libraries (libsignal, RingRTC, WebRTC, libmobilecoin) were also accounted for: libsignal `v0.106.1` and libmobilecoin `6.0.2` are unchanged from 8.36 and their rebuilds carry over, and RingRTC `v2.74.0` with WebRTC `8037b` were rebuilt from source and match, so 8.37 is *fully reproducible from public source*. That covers not just the Signal-iOS repository but every library it bundles.
]

= Method
This is the same method as for #link("https://github.com/commandersaki/signal-ios-build-verification/blob/main/report/report.pdf")[8.35.1], which describes it in full.
+ The source is cloned at the Xcode Cloud path `/Volumes/workspace/repository`.
+ The third-party frameworks and prebuilt binaries are Swift Package Manager packages pinned with exact versions and resolved by `xcodebuild` (8.37 dropped the CocoaPods `Podfile`/`Makefile`).
+ An unsigned `xcodebuild archive` runs with the scheme's App Store Release configuration, using the exact Xcode build recorded in the shipped `Info.plist`.
+ `verify/compare_build.sh` and `verify/explain_residuals.sh` compare the result with the decrypted App Store IPA.

#table(
  columns: (auto, 1fr),
  table.header([Input], [Value]),
  [App Store app], [Signal 8.37 (1993), downloaded from the App Store (version ID `894994822`) and decrypted with #link("https://github.com/DrWhax/unfairplay")[unfairplay]. The encrypted IPA passes all 27,161 of its code-signature page hashes. Decryption changed nothing outside the FairPlay-encrypted ranges apart from the `cryptid` flag.],
  [Source], [Tag `8.37.0.1993`, commit `1c925a184`, the commit recorded in the shipped `Info.plist`. libsignal `0.106.1`, RingRTC `2.74.0` and MobileCoin-Swift `6.0.3-signal.1` at the versions the tag pins.],
  [Toolchain], [Xcode 27.1 (27A9275), matching the shipped `DTXcodeBuild`.],
)

= Results
#table(
  columns: (auto, 1fr),
  table.header([Check], [Result]),
  [`__TEXT,__text`, all 21 binaries], [Byte-identical (69.0 MB, hashed with Apple's `segedit` and `shasum`)],
  [Functions, Signal's 5 binaries], [153,121 of 153,121 match after address normalisation],
  [Strings, symbols, linked libraries], [Identical],
  [Header bytes], [`__LINKEDIT` size (signature) in all 21 binaries; `LC_UUID` in `Signal` and `SignalServiceKit`],
  [GOT slot order], [`Signal` (1,693 + 1 stub bytes) and `SignalServiceKit` (998 + 1 stub bytes). All stubs resolve to the same target.],
  [Plists], [38 differ, only in `BuildDetails` time, `BuildMachineOSBuild`, `CFBundleVersion` and `DTAppStoreToolsBuild`],
  [Asset catalogs], [All renditions identical except the 72 rasterised app-icon bitmaps (renamed randomly by `actool`) and one rasterised rendition each in the main app (`official-wallpaper`) and the share extension (`clock-diver`), whose vector sources are identical],
  [Loose icons], [107 of 14,400 and 176 of 23,104 pixels differ, by at most 1/255 in one channel],
  [Prebuilt native libraries], [libsignal `v0.106.1` and libmobilecoin `6.0.2` unchanged from 8.36, whose rebuilds carry over; RingRTC `v2.74.0` rebuilt and byte-identical; WebRTC `8037b` rebuilt, `__TEXT,__text` byte-identical and the whole binary differing only in `LC_UUID` and one linker marker. See below.],
)

= Prebuilt native libraries
libsignal `v0.106.1` and libmobilecoin `6.0.2` are pinned to exactly the binaries verified for 8.36, so no rebuild is needed here and the earlier results carry over (#link("https://github.com/commandersaki/signal-ios-build-verification/blob/main/versions/8.36.0.1981/out/deps/README.md")[8.36 deps] and #link("https://github.com/commandersaki/signal-ios-build-verification/blob/main/versions/8.35.1.1964/out/deps/README.md")[8.35.1 deps]).

RingRTC `v2.74.0` and WebRTC `8037b` are new pins for 8.37, so they were rebuilt from source and compared with the pinned prebuilds:
- RingRTC `v2.74.0` was built with `verify/deps/build_ringrtc.sh` (Rust 1.97.1, Xcode 26.2 at the runner's paths) and its `libringrtc.a` matches the pinned `ringrtc-ios-build-v2.74.0.xcframework.zip` byte for byte.
- WebRTC `8037b` was built with `verify/deps/build_webrtc.sh` (Xcode 26.1.1) and its arm64 slice matches the bundled `WebRTC.framework` apart from two things: the 16-byte `LC_UUID`, and one `radr://5614542` linker-synthesised marker symbol (with ~96 bytes of associated string-table data). The linker emits that marker on Signal's macOS 15 CI host but not on the macOS 26 host used here — a build-host linker artifact, not source code. `__TEXT,__text` is byte-identical.

With the app's own code also byte-identical, every compiled byte in 8.37 traces back to public source: the equivalent of a source-reproducible build. Scripts: `verify/deps/`; outputs: `out/deps/`.

= Limitations
As for earlier versions:
- The public source itself is not reviewed.
- The toolchains are trusted: Apple's Xcode compilers, the Rust toolchains from rustup and Chromium's prebuilt clang. A compromised compiler would reproduce its own output.
- The causes of the UUID and icon-rasterisation differences are inferred, not proven.

= Reproducing
```sh
git clone https://github.com/signalapp/Signal-iOS.git /Volumes/workspace/repository
cd /Volumes/workspace/repository && git checkout 8.37.0.1993
# xcodebuild archive with Xcode 27.1 (27A9275), then:
verify/compare_build.sh signal-ios-8.37.0-1993.decrypted.ipa <built Signal.app> versions/8.37.0.1993/out/ipa_vs_build
verify/explain_residuals.sh signal-ios-8.37.0-1993.decrypted.ipa <built Signal.app> versions/8.37.0.1993/out/residuals
```
The decrypted IPA is attached to the #link("https://github.com/commandersaki/signal-ios-build-verification/releases/tag/signal-8.37.0.1993")[`signal-8.37.0.1993` release], and all outputs are in `versions/8.37.0.1993/out/`.

= Changelog
#table(
  columns: (auto, 1fr),
  table.header([Date], [Change]),
  [12 November 2026], [First published version.],
)
