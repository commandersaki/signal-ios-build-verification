# Signal iOS 8.36.1 (build 1988)

**Result:** the compiled code (`__TEXT,__text`) of all 21 binaries in the App Store app is **byte-identical** to a local build of tag [`8.36.1.1988`](https://github.com/signalapp/Signal-iOS/tree/8.36.1.1988) with Xcode 27.1 (27A9275). The remaining differences are the signature-size field, one UUID and GOT-slot order in `SignalUI` (every stub resolves to the same target), build metadata in plists, app icons rasterised at build time (at most 1/255 per channel), and one further rasterised rendition whose vector source is identical. All four prebuilt libraries are pinned to the versions rebuilt for 8.36, so this release is fully reproducible from public source.

- Report: [`report.pdf`](report.pdf) (source: [`report.typ`](report.typ))
- Decrypted IPA: [`signal-8.36.1` release](https://github.com/commandersaki/signal-ios-build-verification/releases/tag/signal-8.36.1)
- Outputs: [`out/`](out/)
