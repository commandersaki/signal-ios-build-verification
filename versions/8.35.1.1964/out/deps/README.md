# Prebuilt native libraries rebuilt from source (Signal iOS 8.35.1; also used by 8.36)

Each library was rebuilt with [`verify/deps/build_*.sh`](../../../../verify/deps/) and compared with the pinned prebuild (device slice, `aarch64-apple-ios` / `ios-arm64`).

| Library | Pinned artifact (checksum) | Prebuilt device library SHA-256 | Rebuilt SHA-256 | Result |
|---|---|---|---|---|
| libsignal `v0.105.0` | `libsignal-client-ios-build-v0.105.0.tar.gz` (`556a8241…43faf`, Podfile) | `296840c5af0ca4c2bccd638d19d19741d3f3433221846cd64eaa13100e0bacd2` | same | byte-identical, 803/803 members |
| RingRTC `v2.73.0` | `ringrtc-ios-build-v2.73.0.tar.bz2` (`eb2579b7…f88a`, Podfile) | `f9614059c2409e6f9e8f5772c390b977d0eab305765d16c62e7b151b305edd5e` | same | byte-identical, 579/579 members |
| WebRTC `8037a` | `WebRTC.xcframework` in the RingRTC v2.73.0 prebuild | `1c65344f…798a` (signed); `__text` `38388eac05929b0a952949e4f670155aad4c3129fe934839b829389ceb337ee7` | `__text` same | identical except the 8-byte `LC_UUID` (signatures removed) |
| libmobilecoin `6.0.2` | [`signalapp/libmobilecoin-apple-artifacts` @ `223aeac`](https://github.com/signalapp/libmobilecoin-apple-artifacts/tree/223aeac316addcae8abcc5398b347123d16c2fce) (Git LFS); in 8.36 `libmobilecoin-ios-build-v6.0.2.zip` (`bd99aff5…bf26`) | `ebfa6710db23a963e4fa4c2f248a34d67533a8b5f4221d1b6d24157ad0556c21` | same | byte-identical, 602/602 members |

Files:
- [`libsignal-v0.105.0_compare.json`](libsignal-v0.105.0_compare.json), [`ringrtc-v2.73.0_compare.json`](ringrtc-v2.73.0_compare.json), [`libmobilecoin-6.0.2_compare.json`](libmobilecoin-6.0.2_compare.json): output of [`verify/ar_compare.py`](../../../../verify/ar_compare.py)
- [`webrtc-8037a_bytediff.json`](webrtc-8037a_bytediff.json): output of [`verify/bytediff.py`](../../../../verify/bytediff.py) (thinned arm64, signatures removed)
- [`webrtc-8037a_prebuilt_build_env.txt`](webrtc-8037a_prebuilt_build_env.txt): recorded by Signal's WebRTC build
- [`libsignal-v0.105.0_ci_log_excerpt.txt`](libsignal-v0.105.0_ci_log_excerpt.txt): Signal's public [CI run 37556000811](https://github.com/signalapp/libsignal/actions/runs/37556000811)

Every script was run twice from scratch with the same results.
