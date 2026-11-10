// Signal iOS 8.36.1 — source-to-binary verification
#set document(title: "Signal iOS 8.36.1: Source-to-Binary Verification", author: "commandersaki")
#set page(paper: "a4", margin: (x: 2.2cm, y: 2.2cm), numbering: "1 / 1",
  header: context { if counter(page).get().first() > 1 [
    #set text(8pt, fill: luma(110))
    Signal iOS 8.36.1 (1988) — source-to-binary verification #h(1fr) 11 November 2026
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
  #text(20pt, weight: "bold")[Signal iOS 8.36.1 (build 1988)]\
  #v(0.2em)
  #text(14pt)[Source-to-binary verification of the App Store build]\
  #v(0.8em)
  #text(10pt, fill: luma(80))[Prepared by commandersaki with Claude Code · 11 November 2026]
  #v(0.5cm)
]

#note[
  *Result.* The compiled code (`__TEXT,__text`) of all 21 binaries in the App Store app is *byte-identical* to a local build of tag `8.36.1.1988` with Xcode 27.1 (27A9275). That covers Signal's five own binaries and all 16 bundled frameworks. Every other difference is one already explained for earlier versions: the signature-size field in every binary; the UUID and the linker's GOT-slot order in `SignalUI` alone, with every stub resolving to the same target; build metadata in plists; the app icons, which are rasterised at build time and differ by at most 1/255; and one further rasterised rendition in the share extension whose vector source is identical.

  Its four prebuilt native libraries (libsignal, RingRTC, WebRTC, libmobilecoin) are pinned to exactly the versions rebuilt and matched for 8.36, so 8.36.1 is *fully reproducible from public source*. That covers not just the Signal-iOS repository but every library it bundles.
]

= Method
This is the same method as for #link("https://github.com/commandersaki/signal-ios-build-verification/blob/main/report/report.pdf")[8.35.1], which describes it in full.
+ The source is cloned at the Xcode Cloud path `/Volumes/workspace/repository`.
+ `make dependencies` fetches the dependencies.
+ An unsigned `xcodebuild archive` runs with the scheme's App Store Release configuration, using the exact Xcode build recorded in the shipped `Info.plist`.
+ `verify/compare_build.sh` and `verify/explain_residuals.sh` compare the result with the decrypted App Store IPA.

#table(
  columns: (auto, 1fr),
  table.header([Input], [Value]),
  [App Store app], [Signal 8.36.1 (1988), downloaded from the App Store (version ID `894922328`) and decrypted with #link("https://github.com/DrWhax/unfairplay")[unfairplay]. The encrypted IPA passes all 26,778 of its code-signature page hashes. Decryption changed nothing outside the FairPlay-encrypted ranges apart from the `cryptid` flag.],
  [Source], [Tag `8.36.1.1988`, commit `7cb8619`, the commit recorded in the shipped `Info.plist`. Pods submodule `fae00ed`; libsignal `0.106.1` (Swift Package Manager) and RingRTC `v2.73.0`, at the versions the tag pins.],
  [Toolchain], [Xcode 27.1 (27A9275), matching the shipped `DTXcodeBuild`.],
)

= Results
#table(
  columns: (auto, 1fr),
  table.header([Check], [Result]),
  [`__TEXT,__text`, all 21 binaries], [Byte-identical (68.2 MB, hashed with Apple's `segedit` and `shasum`)],
  [Functions, Signal's 5 binaries], [150,346 of 150,346 match after address normalisation],
  [Strings, symbols, linked libraries], [Identical],
  [Header bytes], [`__LINKEDIT` size (signature) in all 21 binaries; `LC_UUID` in `SignalUI` only],
  [GOT slot order], [`SignalUI` only (1 + 1,162 stub bytes). All 1,750 + 1,162 stubs resolve to the same target.],
  [Plists], [38 differ, only in `BuildDetails` time, `BuildMachineOSBuild`, `CFBundleVersion` and `DTAppStoreToolsBuild`],
  [Asset catalogs], [All renditions identical (2,832 main, 8 NSE), except the 72 rasterised app-icon bitmaps (main) and one raster `reactions-megaphone-bg` (share extension, Scale 1 only), which `actool` rasterises at build time from an identical vector source],
  [Loose icons], [107 of 14,400 and 176 of 23,104 pixels differ, by at most 1/255 in one channel],
  [Prebuilt native libraries], [All four pins unchanged from 8.36, whose rebuilds carry over: libsignal `v0.106.1` byte-identical (803 of 803 members), RingRTC `v2.73.0`, WebRTC `8037a` and libmobilecoin `6.0.2` (byte-identical, WebRTC apart from its 8-byte UUID). See below.],
)

= Prebuilt native libraries
All four prebuilt libraries are pinned to exactly the versions verified for 8.36, so no rebuild is needed here and the earlier results carry over: libsignal `v0.106.1` was rebuilt from source for 8.36 (#link("https://github.com/commandersaki/signal-ios-build-verification/blob/main/versions/8.36.0.1981/out/deps/README.md")[8.36 deps]), and RingRTC `v2.73.0`, WebRTC `8037a` and libmobilecoin `6.0.2` were rebuilt for 8.35.1 (#link("https://github.com/commandersaki/signal-ios-build-verification/blob/main/versions/8.35.1.1964/out/deps/README.md")[8.35.1 deps]). With the app's own code also byte-identical, every compiled byte in 8.36.1 traces back to public source: the equivalent of a source-reproducible build. Scripts: `verify/deps/`; outputs: `out/deps/`.

= Limitations
As for earlier versions:
- The public source itself is not reviewed.
- The toolchains are trusted: Apple's Xcode compilers, the Rust toolchains from rustup and Chromium's prebuilt clang. A compromised compiler would reproduce its own output.
- The causes of the UUID and icon-rasterisation differences are inferred, not proven.

= Reproducing
```sh
git clone https://github.com/signalapp/Signal-iOS.git /Volumes/workspace/repository
cd /Volumes/workspace/repository && git checkout 8.36.1.1988 && make dependencies
# xcodebuild archive with Xcode 27.1 (27A9275), as in the 8.35.1 report, then:
verify/compare_build.sh signal-ios-8.36.1-1988.decrypted.ipa <built Signal.app> versions/8.36.1.1988/out/ipa_vs_build
verify/explain_residuals.sh signal-ios-8.36.1-1988.decrypted.ipa <built Signal.app> versions/8.36.1.1988/out/residuals
```
The decrypted IPA is attached to the #link("https://github.com/commandersaki/signal-ios-build-verification/releases/tag/signal-8.36.1")[`signal-8.36.1` release]. The app is also in `versions/8.36.1.1988/signal_dec/`, and all outputs are in `versions/8.36.1.1988/out/`.

= Changelog
#table(
  columns: (auto, 1fr),
  table.header([Date], [Change]),
  [11 November 2026], [First published version.],
)
