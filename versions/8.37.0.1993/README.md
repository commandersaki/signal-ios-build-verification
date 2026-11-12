# Signal iOS 8.37 (build 1993)

**Result:** the compiled code (`__TEXT,__text`) of all 21 binaries in the App Store app is **byte-identical** to a local build of tag [`8.37.0.1993`](https://github.com/signalapp/Signal-iOS/tree/8.37.0.1993) with Xcode 27.1 (27A9275). The remaining differences are the signature-size field in every binary; the UUID and GOT-slot order in `Signal` and `SignalServiceKit` (every stub resolves to the same target); build metadata in plists; the two app icons (at most 1/255 per channel); and two rasterised renditions (`official-wallpaper`, `clock-diver`) whose vector sources are identical.

This release migrated from CocoaPods to Swift Package Manager: the bundled frameworks are now SPM `_PackageProduct` frameworks. The four prebuilt native libraries are all accounted for — libsignal `v0.106.1` and libmobilecoin `6.0.2` carry over from 8.36, and RingRTC `v2.74.0` and WebRTC `8037b` were rebuilt from source and matched. This release is fully reproducible from public source.

- Report: [`report.pdf`](report.pdf) (source: [`report.typ`](report.typ))
- Decrypted IPA: [`signal-8.37.0.1993` release](https://github.com/commandersaki/signal-ios-build-verification/releases/tag/signal-8.37.0.1993)
- Outputs: [`out/`](out/)
