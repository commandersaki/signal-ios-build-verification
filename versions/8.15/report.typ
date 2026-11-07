// Signal iOS 8.15 — source-to-binary verification
#set document(title: "Signal iOS 8.15: Source-to-Binary Verification", author: "commandersaki")
#set page(paper: "a4", margin: (x: 2.2cm, y: 2.2cm), numbering: "1 / 1",
  header: context { if counter(page).get().first() > 1 [
    #set text(8pt, fill: luma(110))
    Signal iOS 8.15 (1655) — source-to-binary verification #h(1fr) 7 November 2026
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
  #text(20pt, weight: "bold")[Signal iOS 8.15 (build 1655)]\
  #v(0.2em)
  #text(14pt)[Source-to-binary verification of the App Store build]\
  #v(0.8em)
  #text(10pt, fill: luma(80))[Prepared by commandersaki with Claude (Opus 5.5, Anthropic) in Claude Code · 7 November 2026]
  #v(0.5cm)
]

#note[
  *Result.* The compiled code (`__TEXT,__text`) of all 23 binaries in the App Store app is *byte-identical* to a local build of tag `8.15.0.1655` with Xcode 26.5 (17F42). That covers Signal's five own binaries and all 18 bundled frameworks. Every other difference falls into a category already explained in the #link("https://github.com/commandersaki/signal-ios-build-verification/blob/main/versions/8.14/report.pdf")[8.14 report]: signature size, UUID, linker GOT-slot order (with every stub and pointer resolving to the same target), build metadata in plists, and bitmaps rasterised at build time from identical sources.
]

= Method
This is the same method as #link("https://github.com/commandersaki/signal-ios-build-verification/blob/main/report/report.pdf")[8.35.1] and #link("https://github.com/commandersaki/signal-ios-build-verification/blob/main/versions/8.14/report.pdf")[8.14], which describe it in full.
+ The source is cloned at the Xcode Cloud path `/Volumes/workspace/repository`.
+ `make dependencies` fetches the dependencies.
+ An unsigned `xcodebuild archive` runs with the scheme's App Store Release configuration, using the exact Xcode build recorded in the shipped `Info.plist`.
+ `verify/compare_build.sh` and `verify/explain_residuals.sh` compare the result with the decrypted App Store IPA.

#table(
  columns: (auto, 1fr),
  table.header([Input], [Value]),
  [App Store app], [`org.whispersystems.signal_8.15.decrypted.ipa` from #link("https://github.com/BarbossHack/reproducible-LFS/tree/master/Signal-iOS")[BarbossHack/reproducible-LFS], SHA-256 `7629023a…6ad7e4`. Version 8.15, build 1655. Every code-signature page outside the FairPlay-encrypted ranges matches Apple's signature.],
  [Source], [Tag `8.15.0.1655`, commit `a619caa`, the commit recorded in the shipped `Info.plist`. Pods submodule `1a4acf8`.],
  [Toolchain], [Xcode 26.5 (17F42), iOS SDK 26.5 (23F73), matching the shipped `DTXcodeBuild` and `DTSDKBuild`.],
)

= Results
#table(
  columns: (auto, 1fr),
  table.header([Check], [Result]),
  [`__TEXT,__text`, all 23 binaries], [Byte-identical (65.6 MB, hashed with Apple's `segedit` and `shasum`)],
  [Functions, Signal's 5 binaries], [144,193 of 144,193 match after address normalisation],
  [Strings, symbols, linked libraries], [Identical],
  [Header bytes], [`__LINKEDIT` size (signature) in all 23 binaries; `LC_UUID` in 13 binaries],
  [GOT slot order], [`Signal` (1,668 stub bytes), `SignalUI` (1,159), `LibMobileCoin` (4) and `SignalServiceKit` (19 relative pointers in `__const`). Every stub and pointer resolves to the same target.],
  [Plists], [26 differ, only in `BuildDetails` time, `BuildMachineOSBuild`, `CFBundleVersion` and `DTAppStoreToolsBuild`],
  [Icons and asset catalogs], [The two loose icons differ by at most 8/255 per channel. In the catalogs, 8 + 8 rasterised renditions differ; each comes from a vector source that is identical in both builds, or is a packed atlas of such images. The NSE catalog is identical.],
)

These residual differences are the ones Telegram's `ipadiff.py` does not normalise. Run on this build, it flags exactly the seven files BarbossHack's #link("https://github.com/BarbossHack/reproducible/actions/runs/27652244318")[8.15 run] reported: `Signal`, `SignalUI`, `SignalServiceKit`, `LibMobileCoin`, `Info.plist` and the two icons.

= Limitations
As for earlier versions:
- The public source itself is not reviewed.
- Prebuilt dependencies (libsignal, RingRTC, WebRTC, LibMobileCoin) are checked against their pinned versions, not rebuilt from their own source.
- The causes of the UUID and rasterisation differences are inferred, not proven.

= Reproducing
```sh
git clone https://github.com/signalapp/Signal-iOS.git /Volumes/workspace/repository
cd /Volumes/workspace/repository && git checkout 8.15.0.1655 && make dependencies
# xcodebuild archive with Xcode 26.5 (17F42), as in the 8.35.1 report, then:
verify/compare_build.sh org.whispersystems.signal_8.15.decrypted.ipa <built Signal.app> versions/8.15/out/ipa_vs_build
verify/explain_residuals.sh org.whispersystems.signal_8.15.decrypted.ipa <built Signal.app> versions/8.15/out/residuals
```
The decrypted IPA is attached to the #link("https://github.com/commandersaki/signal-ios-build-verification/releases/tag/signal-8.15")[`signal-8.15` release]. The app is also in `versions/8.15/signal_dec/`, and all outputs are in `versions/8.15/out/`.
