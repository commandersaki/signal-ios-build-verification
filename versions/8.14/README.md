# Signal iOS 8.14 (build 1637)

A follow-up to [BarbossHack's reproducibility check](https://community.signalusers.org/t/add-reproducible-builds-to-the-ios-app/20516/17), which marked 8.14 as not reproducible.

**Result:** the compiled code (`__TEXT,__text`) of all 23 binaries in the App Store app, Signal's five plus all 18 bundled frameworks, is **byte-identical** to a local build of tag [`8.14.0.1637`](https://github.com/signalapp/Signal-iOS/tree/8.14.0.1637) made with Xcode 26.5 (17F42). Every file his check flagged is explained:
- `SignalUI`, `SignalServiceKit` and `LibMobileCoin` differ only in linker GOT-slot order, which varies between builds. Every affected stub and pointer resolves to the same target.
- `Info.plist` differs only in build metadata.
- Two app icons are rasterised at build time and differ by at most 8/255 per channel.

- Report: [`report.pdf`](report.pdf) (source: `report.typ`)
- `signal_dec/Payload/Signal.app`: BarbossHack's decrypted App Store app, from [`BarbossHack/reproducible-LFS`](https://github.com/BarbossHack/reproducible-LFS/tree/master/Signal-iOS) (`org.whispersystems.signal_8.14.decrypted.ipa`, SHA-256 `8a836442d58befa1d1806f5043fc6a3b3051cafc9e46e6f45ca328d501d77e1d`). A separate download decrypted with unfairplay is byte-identical to it, file for file.
- `out/`: outputs:
  - `ipa_vs_build/`: strings, symbols and functions of the five first-party binaries.
  - `residuals/`: every other differing byte and file.
  - `ipadiff_*.txt`: Telegram's `ipadiff.py` run on both local builds.

The scripts are the shared ones in [`../../verify`](../../verify). `explain_residuals.sh` and its helpers were added for this version; the scripts used for 8.35.1 are unchanged.
