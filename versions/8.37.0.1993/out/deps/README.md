# Prebuilt native libraries (Signal iOS 8.37)

Each changed pin was rebuilt with [`verify/deps/build_*.sh`](../../../../verify/deps/) and compared with the pinned prebuild (device slice, `aarch64-apple-ios` / `ios-arm64`). Unchanged pins carry over their earlier result.

| Library | Pinned artifact (checksum) | Result |
|---|---|---|
| libsignal `v0.106.1` | `libsignal-client-ios-build-v0.106.1.xcframework.zip` (`60baf6a3…a77`) | unchanged from 8.36; byte-identical rebuild carried over |
| RingRTC `v2.74.0` | `ringrtc-ios-build-v2.74.0.xcframework.zip` (`789d702a…1104`) | rebuilt, byte-identical: 579/579 members, SHA-256 `4e5d9abc…7cc3e` |
| WebRTC `8037b` | `webrtc-8037b-ios-release.xcframework.zip` (`8c3eddaf…cbfb`) | rebuilt, `__TEXT,__text` byte-identical; whole arm64 binary differs only in `LC_UUID` and one `radr://5614542` linker marker |
| libmobilecoin `6.0.2` | `libmobilecoin-ios-build-v6.0.2.zip` (`bd99aff5…bf26`) | unchanged from 8.36; byte-identical rebuild carried over |

Details:

- **libsignal `v0.106.1`** and **libmobilecoin `6.0.2`** are pinned to exactly the binaries verified for 8.36. See [`versions/8.36.0.1981/out/deps/`](../../../8.36.0.1981/out/deps/) and [`versions/8.35.1.1964/out/deps/`](../../../8.35.1.1964/out/deps/). MobileCoin-Swift bumped its *Swift wrapper* to `6.0.3-signal.1`, but that wrapper is compiled during the app build; its pinned native binary is still `libmobilecoin-ios-build-v6.0.2.zip`.

- **RingRTC `v2.74.0`** was rebuilt with `build_ringrtc.sh v2.74.0` (Rust 1.97.1, Xcode 26.2 at `/Applications/Xcode_26.2.app`) and is byte-identical to the `ios-arm64/libringrtc.a` in the pinned XCFramework: [`ringrtc-v2.74.0_compare.json`](ringrtc-v2.74.0_compare.json), 579/579 members, SHA-256 `4e5d9abca6c8bc3a86a173ef0d4c51c5be552e2d79eb76be1ade806b92f7cc3e`.

- **WebRTC `8037b`** was rebuilt with `build_webrtc.sh` (Xcode 26.1.1 at `/Applications/Xcode_26.1.1.app`) and its arm64 slice matches the bundled `WebRTC.framework` apart from two things: the 16-byte `LC_UUID` (build identifier) and one `radr://5614542` linker-synthesised marker symbol plus ~96 bytes of associated string-table data (`_exit`, `_time`, `_semaphore_create/wait/signal`, `_kCFBooleanTrue`). The linker emits that marker on Signal's `macos-15-xlarge` CI host but not on the macOS 26 host used here, so it is a build-host linker artifact, not source code. `__TEXT,__text` is byte-identical: SHA-256 `a68b80f030421e7b95c34ebe765684dcd65c0a4b3fe06f03275ae10b9bdccff0`. Comparison: [`webrtc-8037b_bytediff.json`](webrtc-8037b_bytediff.json) (thinned arm64, signatures removed).
