# Signal iOS 8.38 (build 2011)

**Result:** the compiled code (`__TEXT,__text`) of all 21 binaries in the App Store app is **byte-identical** to a local build of tag [`8.38.0.2011`](https://github.com/signalapp/Signal-iOS/tree/8.38.0.2011) with Xcode 27.1 (27A9275). The remaining differences are the signature-size field in every binary (1–2 bytes each, the only byte difference in any binary); build metadata in plists; the two app icons (at most 1/255 per channel); and two rasterised renditions in the share extension (`homescreen_ios`, `reactions-megaphone-bg`) whose vector sources are identical.

The four prebuilt native libraries are all accounted for: libsignal `v0.107.0`, RingRTC `v2.75.0` and WebRTC `8037e` were rebuilt from source and matched (WebRTC apart from its build UUID), and libmobilecoin `6.0.2` carries over from 8.36. This release is fully reproducible from public source. That says nothing about whether the source itself is trustworthy.

- Report: [`report.pdf`](report.pdf) (source: [`report.typ`](report.typ))
- Decrypted IPA: [`signal-8.38.0.2011` release](https://github.com/commandersaki/signal-ios-build-verification/releases/tag/signal-8.38.0.2011)
- Outputs: [`out/`](out/), prebuilt libraries: [`out/deps/`](out/deps/)
