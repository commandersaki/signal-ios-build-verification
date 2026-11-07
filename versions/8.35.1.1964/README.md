# Signal iOS 8.35.1 (build 1964)

The report for this version is [`report/report.pdf`](../../report/report.pdf), at its original path. Its commands refer to `signal_dec/` and `verify/out/`; those files are now here.

- `signal_dec/Payload/Signal.app`: the decrypted App Store app (decrypted with [unfairplay](https://github.com/DrWhax/unfairplay)). The decrypted IPA is attached to the [`signal-8.35.1` release](https://github.com/commandersaki/signal-ios-build-verification/releases/tag/signal-8.35.1).
- `out/`: outputs, including the planted-backdoor controls (`out/controls/`) and the decryption validation (`out/decryption_validation.json`). Per-binary SHA-256 hashes are in `out/provenance_ipa.txt`.
