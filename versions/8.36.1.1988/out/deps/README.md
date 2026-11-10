# Prebuilt native libraries (Signal iOS 8.36.1)

Every pin is unchanged from 8.36, so the 8.36 rebuild results carry over and no library was rebuilt for this release.

| Library | Pin (8.36.1 = 8.36) | Where the rebuild is recorded |
|---|---|---|
| libsignal `v0.106.1` | `libsignal-client-ios-build-v0.106.1.xcframework.zip` (`60baf6a3…`, [`BinaryDependencies/Package.swift`](https://github.com/signalapp/Signal-iOS/blob/8.36.1.1988/BinaryDependencies/Package.swift)) | [8.36 deps](../../../8.36.0.1981/out/deps/) |
| RingRTC `v2.73.0` | [`Podfile`](https://github.com/signalapp/Signal-iOS/blob/8.36.1.1988/Podfile), checksum `eb2579b7…f88a` | [8.35.1 deps](../../../8.35.1.1964/out/deps/) |
| WebRTC `8037a` | RingRTC `v2.73.0` `config/version.properties` | [8.35.1 deps](../../../8.35.1.1964/out/deps/) |
| libmobilecoin `6.0.2` | MobileCoin-Swift `6.0.3-signal.1` ([`project.pbxproj`](https://github.com/signalapp/Signal-iOS/blob/8.36.1.1988/Signal.xcodeproj/project.pbxproj)) → `libmobilecoin-ios-build-v6.0.2.zip` | [8.35.1 deps](../../../8.35.1.1964/out/deps/) |

All four were rebuilt with [`verify/deps/build_*.sh`](../../../../verify/deps/) and matched byte-for-byte (WebRTC apart from its 8-byte `LC_UUID`).
