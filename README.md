# signal-ios-build-verification

Checks whether App Store builds of **Signal iOS** match their public source code, version by version.

**Result so far:** for every version checked, the compiled code (`__TEXT,__text`) of the App Store app is **byte-identical** to a local build of the matching Signal-iOS tag with the Xcode build Signal used. Every remaining difference is accounted for and harmless:
- signature size and UUIDs
- linker GOT-slot ordering that varies between builds of the same source, with every stub still resolving to the same target
- build metadata in plists
- images rasterised at build time from identical sources

**Prebuilt libraries too:** for 8.35.1, 8.36 and 8.36.1, every prebuilt native library the app bundles (libsignal, RingRTC, WebRTC, libmobilecoin) was also rebuilt from its own public source and matches the shipped binary (byte-identical, WebRTC apart from its build UUID). Those versions are therefore **fully reproducible from public source**. The scripts are in `verify/deps/`.

This shows the shipped apps are built from the public source. It does **not** show that the public source itself is free of backdoors. See the limitations in each report.

## Versions

| Version | Result | Report | Files |
|---|---|---|---|
| 8.35.1 (1964) | `__text` byte-identical in all first-party binaries; all four prebuilt native libraries rebuilt from source and matched (fully reproducible from public source); two planted-backdoor controls detected | [`report/report.pdf`](report/report.pdf) | [`versions/8.35.1.1964/`](versions/8.35.1.1964/) |
| 8.14 (1637) | `__text` byte-identical in all 23 binaries; explains why [BarbossHack's check](https://community.signalusers.org/t/add-reproducible-builds-to-the-ios-app/20516/17) flagged it; of the prebuilt libraries only libmobilecoin rebuilt | [`versions/8.14.0.1637/report.pdf`](versions/8.14.0.1637/report.pdf) | [`versions/8.14.0.1637/`](versions/8.14.0.1637/) |
| 8.15 (1655) | `__text` byte-identical in all 23 binaries; of the prebuilt libraries only libmobilecoin rebuilt | [`versions/8.15.0.1655/report.pdf`](versions/8.15.0.1655/report.pdf) | [`versions/8.15.0.1655/`](versions/8.15.0.1655/) |
| 8.36 (1981) | `__text` byte-identical in all 21 binaries; all four prebuilt native libraries rebuilt from source and matched (fully reproducible from public source) | [`versions/8.36.0.1981/report.pdf`](versions/8.36.0.1981/report.pdf) | [`versions/8.36.0.1981/`](versions/8.36.0.1981/) |
| 8.36.1 (1988) | `__text` byte-identical in all 21 binaries; all four prebuilt libraries unchanged from 8.36, whose rebuilds carry over (fully reproducible from public source) | [`versions/8.36.1.1988/report.pdf`](versions/8.36.1.1988/report.pdf) | [`versions/8.36.1.1988/`](versions/8.36.1.1988/) |
| 8.37 (1993) | `__text` byte-identical in all 21 binaries; libsignal and libmobilecoin carry over from 8.36, RingRTC and WebRTC rebuilt from source and matched (fully reproducible from public source) | [`versions/8.37.0.1993/report.pdf`](versions/8.37.0.1993/report.pdf) | [`versions/8.37.0.1993/`](versions/8.37.0.1993/) |

Each `versions/<tag>/` folder holds that version's outputs (`out/`) and, where there is one, its report. The 8.35.1 report stays at `report/report.pdf`, its original path. The decrypted app itself is distributed as an IPA attached to a [release](https://github.com/commandersaki/signal-ios-build-verification/releases) per version.

- Harness: `verify/` (Python standard library + Apple command-line tools). The scripts accept an `.ipa` or an `.app` folder.
- Planted-backdoor controls (8.35.1): `verify/controls/*.patch`

## Reproducing

You need a Mac with the Xcode build recorded in the app's `Info.plist` (`DTXcodeBuild`). For 8.35.1, 8.36 and 8.36.1 that's Xcode 27.1 (27A9275), and for 8.14 and 8.15 it's 26.5 (17F42). Fetch the decrypted IPA from the version's [release](https://github.com/commandersaki/signal-ios-build-verification/releases), build the tag at `/Volumes/workspace/repository` (see the report, §10 for 8.35.1), and compare. To check the decrypted app independently, decrypt your own copy — for example with [unfairplay](https://github.com/DrWhax/unfairplay) — and compare its per-binary hashes with `versions/<tag>/out/provenance_ipa.txt`. In short, for 8.36:

```sh
wget -O signal-ios-8.36-1981.decrypted.ipa \
  https://github.com/commandersaki/signal-ios-build-verification/releases/download/signal-8.36/signal-ios-8.36-1981.decrypted.ipa
verify/compare_build.sh signal-ios-8.36-1981.decrypted.ipa <built Signal.app> versions/8.36.0.1981/out/ipa_vs_build
verify/explain_residuals.sh signal-ios-8.36-1981.decrypted.ipa <built Signal.app> versions/8.36.0.1981/out/residuals
```

## Contents

- `versions/<tag>/out/`: the comparison outputs for each version, including the per-binary hashes (`provenance_ipa.txt`) you can check a fresh decryption against.
- `original_prompt.txt`: the request that started this work, verbatim.
- `report/`, `verify/`: the 8.35.1 report and the harness.
- `verify/out/`: a pointer to where the 8.35.1 outputs moved.

The full per-function disassembly dumps (several GB) are not included; `verify/compare_build.sh` regenerates them.

## Licensing

The harness, reports and other original material in this repository are released under CC0 (see `LICENSE`). The decrypted IPAs attached to releases are **not** covered by CC0. Signal's own code is AGPL-3.0 (source: https://github.com/signalapp/Signal-iOS), and the bundled third-party frameworks carry their own licences. "Signal" and its logos are trademarks of Signal Messenger, LLC; this repository is not affiliated with Signal.

Prepared by commandersaki with Claude (Anthropic) in Claude Code.
