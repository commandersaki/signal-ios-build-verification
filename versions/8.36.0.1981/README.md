# Signal iOS 8.36 (build 1981)

**Result:** the compiled code (`__TEXT,__text`) of all 21 binaries in the App Store app is **byte-identical** to a local build of tag [`8.36.0.1981`](https://github.com/signalapp/Signal-iOS/tree/8.36.0.1981) with Xcode 27.1 (27A9275). The remaining differences are the signature-size field, one UUID and GOT-slot order in `SignalServiceKit` (every stub resolves to the same target), build metadata in plists, and app icons rasterised at build time (at most 1/255 per channel).

- Report: [`report.pdf`](report.pdf) (source: `report.typ`)
- Decrypted IPA: [`signal-8.36` release](https://github.com/commandersaki/signal-ios-build-verification/releases/tag/signal-8.36)
- Outputs: `out/`
