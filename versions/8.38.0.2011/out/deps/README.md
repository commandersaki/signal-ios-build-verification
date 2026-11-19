# Prebuilt native libraries (Signal iOS 8.38)

Each changed pin was rebuilt with [`verify/deps/build_*.sh`](../../../../verify/deps/) and compared with the pinned prebuild (device slice, `aarch64-apple-ios` / `ios-arm64`). Unchanged pins carry over their earlier result.

| Library | Pinned artifact (checksum) | Result |
|---|---|---|
| libsignal `v0.107.0` | `libsignal-client-ios-build-v0.107.0.xcframework.zip` (`c21686be…5712`) | rebuilt, byte-identical: 803/803 members, SHA-256 `bc926638…69e9` |
| RingRTC `v2.75.0` | `ringrtc-ios-build-v2.75.0.xcframework.zip` (`937d04db…ed19`) | rebuilt, byte-identical: 579/579 members, SHA-256 `929c2d72…a950` |
| WebRTC `8037e` | `webrtc-8037e-ios-release.xcframework.zip` (`84f36bd3…e4cb`) | rebuilt, `__TEXT,__text` byte-identical; whole arm64 binary differs only in the 16-byte `LC_UUID` |
| libmobilecoin `6.0.2` | `libmobilecoin-ios-build-v6.0.2.zip` (`bd99aff5…bf26`) | unchanged from 8.36; byte-identical rebuild carried over |

Details:

- **libsignal `v0.107.0`** was rebuilt with `build_libsignal.sh v0.107.0` (Rust 1.98.1 from the tag's `rust-toolchain`, Xcode 16.4 at `/Applications/Xcode_16.4.app`, both as recorded in the prebuild's strings) and is byte-identical to the `ios-arm64/libsignal_ffi.a` in the pinned XCFramework: [`libsignal-v0.107.0_compare.json`](libsignal-v0.107.0_compare.json), 803/803 members, SHA-256 `bc926638a211bf337510e8dac2700c76d73e47fe854a51cd70ffcdf487ab69e9`.

- **RingRTC `v2.75.0`** was rebuilt with `build_ringrtc.sh v2.75.0` (Rust 1.97.1, Xcode 26.2 at `/Applications/Xcode_26.2.app`) and is byte-identical to the `ios-arm64/libringrtc.a` in the pinned XCFramework: [`ringrtc-v2.75.0_compare.json`](ringrtc-v2.75.0_compare.json), 579/579 members, SHA-256 `929c2d7272d26d229a15f183898fa1afc7b64243add2d6f8f34205194831a950`.

- **WebRTC `8037e`** (signalapp/webrtc commit `f29962d`, five commits on top of `8037b`) was rebuilt with `build_webrtc.sh` (Xcode 26.1.1 at `/Applications/Xcode_26.1.1.app`, matching the prebuild's `build_env.txt`). Its arm64 slice is the same size as the bundled `WebRTC.framework` and differs only in 8 bytes, all inside the 16-byte `LC_UUID` (build identifier). Unlike 8.37's `8037b`, there is no `radr://5614542` linker marker difference this time. `__TEXT,__text` is byte-identical: SHA-256 `bd69e43ad8be21f2d635bf0a4c385b4f8ec88f7aa3ec4ba42eb01d7b0ef7506a`, the same hash as the `WebRTC` binary in the App Store app ([`text_sha256.txt`](../residuals/text_sha256.txt)). Comparison: [`webrtc-8037e_bytediff.json`](webrtc-8037e_bytediff.json) (thinned arm64, signatures removed).

- **libmobilecoin `6.0.2`** is pinned to exactly the binary verified for 8.35.1 and 8.36; MobileCoin-Swift is unchanged from 8.37. See [`versions/8.36.0.1981/out/deps/`](../../../8.36.0.1981/out/deps/) and [`versions/8.35.1.1964/out/deps/`](../../../8.35.1.1964/out/deps/).
