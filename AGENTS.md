# Verifying a new Signal iOS release

Instructions for an agent or person checking that a new App Store build of Signal iOS matches its public source. Read the [8.35.1 report](report/report.pdf) for the full method. Use the [8.36 folder](versions/8.36.0.1981/) as the model for a new release.

Never claim a result that a script did not produce. If a difference is not one of the [known differences](#known-differences), stop and investigate it. Do not explain it away.

## Manual prerequisites

An agent cannot do these alone, because they need a password, a sign-in or a GUI. Run password prompts in a real terminal: a backgrounded command cannot receive them.

**Machine:** an Apple silicon Mac with about 150 GB free for an app build, and more if WebRTC changed.

**Tools:** install with Homebrew: `xcodes`, `ipatool`, `typst`, `gh`, `go`, `rustup`, `protobuf`, `coreutils`.

**App Store access:**
```sh
ipatool auth login --email <your Apple Account>
```

**[unfairplay](https://github.com/DrWhax/unfairplay)**, once per Mac. Use it only with apps you lawfully acquired and accounts you control.
1. Clone it and run `go build -o unfairplay ./cmd/unfairplay`.
2. Sign in to the native Mac App Store.
3. Install an iPhone or iPad app and open it once.
4. Download a matching encrypted IPA with the same Apple Account, using `ipatool`.
5. Run `sudo ./unfairplay setup --app /Applications/App.app --ipa App.ipa`.

The saved model can decrypt other apps from that enrollment. Keep it private, back it up only in encrypted storage, and never put it in this repository or in CI.

**Xcode for the app build:** install the build recorded in the app's `DTXcodeBuild`:
```sh
xcodes install <version> --directory /Applications --experimental-unxip
DEVELOPER_DIR=<Xcode>/Contents/Developer xcodebuild -downloadPlatform iOS
DEVELOPER_DIR=<Xcode>/Contents/Developer xcodebuild -downloadComponent MetalToolchain
```

**Prebuilt-library rebuilds:** needed only when a pin changes.
```sh
sudo mkdir -p /Users/runner /Users/signal /usr/local/lib
sudo chown "$USER" /Users/runner /Users/signal
```
Each library needs its Xcode at an exact path, listed under [Prebuilt libraries](#prebuilt-libraries).

**Publishing:** `gh auth login`, plus push access to this repository.

## Steps for a release

1. **Find the tag and version.** Get the tag from [Signal-iOS releases](https://github.com/signalapp/Signal-iOS/releases). The App Store version can appear days before the GitHub release.
2. **Download the IPA.** Run `ipatool list-versions -b org.whispersystems.signal`, then `ipatool get-version-metadata -b org.whispersystems.signal --external-version-id <id>` on the newest IDs. A version can have several IDs, so pick the one whose `CFBundleVersion` matches the tag's build number. Then run `ipatool download` with `--external-version-id`.
3. **Decrypt and validate.**
   ```sh
   ./unfairplay decrypt --input signal-X.ipa --strip-account-data
   python3 -I verify/validate_decryption.py signal-X.ipa signal-X.decrypted.ipa out.json
   ```
   Every encrypted-IPA signature page must verify, and no bytes may change outside the encrypted ranges.
4. **Check the inputs.** The IPA's `Info.plist` must give the tag's commit (`BuildDetails.SignalCommit`), and `DTXcodeBuild` names the Xcode to use.
5. **Make the publishable IPA.** Copy the decrypted IPA and run `zip -d <copy> iTunesMetadata.plist 'META-INF/*' 'META-INF/'`. Unzip its `Payload` to `versions/<tag>/signal_dec/`.
6. **Build at the Xcode Cloud path.** The path matters.
   ```sh
   hdiutil create -size 150g -type SPARSE -fs APFS -volname workspace workspace.sparseimage
   hdiutil attach workspace.sparseimage -nobrowse
   git clone https://github.com/signalapp/Signal-iOS.git /Volumes/workspace/repository
   cd /Volumes/workspace/repository && git checkout <tag>
   export DEVELOPER_DIR=<Xcode>/Contents/Developer
   Scripts/check_xcode_version.py && make dependencies
   xcodebuild archive -workspace Signal.xcworkspace -scheme Signal \
     -destination 'generic/platform=iOS' -derivedDataPath /Volumes/workspace/DerivedData \
     -archivePath /Volumes/workspace/build.xcarchive \
     CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
   ```
   Do not pass `-configuration Release`: the scheme's "App Store Release" configuration is the right one. Use a fresh clone and DerivedData for each version.
7. **Compare.** Run these from this repository, with `DEVELOPER_DIR` still set:
   ```sh
   verify/provenance.sh <ipa> /Volumes/workspace/repository versions/<tag>/out/provenance_ipa.txt
   verify/compare_build.sh <ipa> <built Signal.app> versions/<tag>/out/ipa_vs_build
   python3 -I verify/summarise.py versions/<tag>/out/ipa_vs_build
   verify/explain_residuals.sh <ipa> <built Signal.app> versions/<tag>/out/residuals
   ```
8. **Check the prebuilt libraries** (next section).
9. **Write a short report** at `versions/<tag>/report.typ`, based on the 8.36 report, and build it with `typst compile`. Cover the method briefly, the inputs, a results table and the limitations. Check every number against the script outputs.
10. **Publish only after a person has reviewed the report.** See [Publishing](#publishing).

## Known differences

| Difference | Why it is harmless |
|---|---|
| `__LINKEDIT.vmsize` (1–2 bytes) | Includes the code signature |
| `LC_UUID` | Build identifier, which varies between builds |
| `__stubs`, `__objc_stubs`, and `__TEXT,__const` relative pointers | Linker GOT-slot order varies between builds. `explain_residuals.sh` must show every one resolving to the same target |
| Plists: `BuildDetails` time, `BuildMachineOSBuild`, `CFBundleVersion`, `DTAppStoreToolsBuild` | Build metadata |
| Loose app icons, 72 "Icon Image" renditions | Rasterised at build time, at most a few levels per channel |
| Rasterised renditions and packed atlases (seen with Xcode 26.5) | The vector source must be identical in both catalogs |
| WebRTC in a fat wrapper | App Store thinning; the scripts extract the arm64 slice |

`__TEXT,__text` must be byte-identical in every binary. Anything else is a finding.

## Prebuilt libraries

Compare each pin with the previous release. An unchanged pin carries over the earlier result. For a changed pin, rebuild from source with [`verify/deps/`](verify/deps/) and compare with [`verify/ar_compare.py`](verify/ar_compare.py). Use [`verify/bytediff.py`](verify/bytediff.py) for WebRTC.

| Library | Pin location | Script | Toolchain used for the last verified build |
|---|---|---|---|
| libsignal | `BinaryDependencies/Package.swift` | [`build_libsignal.sh`](verify/deps/build_libsignal.sh) | Xcode 16.4 at `/Applications/Xcode_16.4.app` |
| RingRTC | `Podfile` | [`build_ringrtc.sh`](verify/deps/build_ringrtc.sh) | Xcode 26.2 at `/Applications/Xcode_26.2.app` |
| WebRTC | RingRTC's `config/version.properties` | [`build_webrtc.sh`](verify/deps/build_webrtc.sh) | Xcode 26.1.1 at `/Applications/Xcode_26.1.1.app` |
| libmobilecoin | MobileCoin-Swift's `Package.swift` | [`build_libmobilecoin.sh`](verify/deps/build_libmobilecoin.sh) | Xcode 14.2, temporarily at `/Applications/Xcode.app`; CMake 3.29.3 |

A new library version may use a different toolchain, and the scripts hardcode these Xcode paths. Before building, get the real recipe from the project's CI log, WebRTC's `build_env.txt`, or the compiler versions and paths recorded in the prebuild (`strings`). Each Xcode must sit at the exact recorded path.

Script notes:
- Each script lists its own prerequisites.
- `build_ringrtc.sh` and `build_libmobilecoin.sh` reuse an existing checkout, so delete it first when the tag changes.
- `WEBRTC_VERSION` is compiled into RingRTC. Without it the library differs.
- libmobilecoin needs CMake 3.x with `tools/patch-cmake.sh`'s edit applied to a private copy. Homebrew's CMake 4 fails.

## Pitfalls

- zsh treats `"$tag:Podfile"` as a path modifier. Write `"${tag}:Podfile"`.
- Overriding `HOME` changes what `~` means, so use absolute paths.
- `xcodes install` needs a real terminal for its password.

## Publishing

- **Layout:** `versions/<Signal tag>/` holds `report.typ`, `report.pdf`, `README.md`, `signal_dec/` and `out/`. `report/report.pdf` is linked from public posts, so never move it.
- **Decrypted IPA:** attach the stripped copy to a GitHub release named `signal-<version>`. It is too big for git.
- **Outputs:** publish summaries and `*_diff.json` files, not `*_ref.json`, `*_cand.json` or function dumps.
- **Privacy:** never publish the unfairplay model, encrypted IPAs or their hashes, `iTunesMetadata.plist`, `META-INF/`, or local usernames and paths. Search the outputs for them before committing.
- **Commits:** use the repository's local git identity and UTC timestamps.
- **Published reports:** record later edits in a Changelog section.
- **Markdown:** make every referenced path, file or CI run a link, and check that the links resolve.
- **Wording:** say "fully reproducible from public source" only when every prebuilt library for that version has also been rebuilt and matched. Always state that this says nothing about whether the source itself is trustworthy.
