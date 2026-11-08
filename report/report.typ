// Signal iOS 8.35.1 — source-to-binary equivalence report
#set document(title: "Signal iOS 8.35.1: Source-to-Binary Equivalence", author: "commandersaki")
#set page(paper: "a4", margin: (x: 2.2cm, y: 2.2cm), numbering: "1 / 1",
  header: context { if counter(page).get().first() > 1 [
    #set text(8pt, fill: luma(110))
    Signal iOS 8.35.1 (1964) — source-to-binary equivalence #h(1fr) 7 November 2026
  ] })
#set text(font: ("Helvetica Neue", "Helvetica", "Arial"), size: 10pt, lang: "en")
#set par(justify: true, leading: 0.62em)
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => { v(0.8em); text(14pt, weight: "bold", it); v(0.3em) }
#show heading.where(level: 2): it => { v(0.5em); text(11pt, weight: "bold", it); v(0.15em) }
#show raw.where(block: false): box.with(fill: luma(240), inset: (x: 2.5pt, y: 0pt), outset: (y: 2.5pt), radius: 2pt)
#show raw: set text(font: ("Menlo", "Courier New"), size: 8.6pt)
#show link: set text(fill: rgb("#1a5fb4"))
#set table(stroke: 0.5pt + luma(190), inset: 5pt)
#show table: set par(justify: false)
#show table.cell.where(y: 0): set text(weight: "bold")

#let note(body, color: rgb("#1a5fb4")) = block(width: 100%, fill: color.lighten(90%), stroke: (left: 3pt + color), inset: 9pt, radius: 2pt, body)
#let ok = text(fill: rgb("#1f7a3a"), weight: "bold")[✓]
#let warn = text(fill: rgb("#a35a00"), weight: "bold")[!]

// ---------- Title ----------
#align(center)[
  #v(1.2cm)
  #text(20pt, weight: "bold")[Signal iOS 8.35.1 (build 1964)]\
  #v(0.2em)
  #text(14pt)[Source-to-binary equivalence of the App Store build]\
  #v(0.8em)
  #text(10pt, fill: luma(80))[Prepared by commandersaki with Claude (Opus 5.5, Anthropic) in Claude Code · 7 November 2026]
  #v(0.6cm)
]

#note[
  *Summary.* The App Store build of Signal iOS 8.35.1 (1964) was decrypted. Then the public source at tag `8.35.1.1964` (commit `4f019b8`) was built with the same Xcode (27.1, build 27A9275). For all five binaries compiled from Signal's own source (`Signal`, `SignalServiceKit`, `SignalUI`, `SignalNSE`, `SignalShareExtension`), *the compiled code section (`__TEXT,__text`) is byte-identical to the shipped app*. Every other differing byte in those binaries was traced to a specific harmless cause. With the code signature removed, the shipped main executable differs from a local build by *one byte*, the signature-size field. 18 of the 19 bundled third-party frameworks are identical apart from that same field. The remaining one, WebRTC, matches once the App Store's architecture thinning is accounted for. Two planted-backdoor builds were both detected, including a one-line change that adds no strings or symbols.

  *Update (8 November 2026):* the prebuilt native libraries the app bundles were then rebuilt from their own public source: libsignal (`v0.105.0`), RingRTC (`v2.73.0`), WebRTC (`8037a`) and libmobilecoin (`6.0.2`). All four match the shipped prebuilds: byte-identical, apart from WebRTC's 8-byte build UUID (@deps).

  This shows that the shipped app is *fully reproducible from public source*. That covers not just the Signal-iOS repository but every prebuilt native library the app bundles, each rebuilt from its own public repository with that project's own recipe. Every compiled byte traces back to public source. The only differences are the code signature, build UUIDs and linker GOT-slot order, all explained in @bytes and @deps. It does not show that the public source itself is trustworthy (see @limits).
]

#outline(depth: 1, indent: 1em)

// ---------- 1 ----------
= Original request
The request that started this work, verbatim:

```text
This is the signal ios git clone, it is open source.

I have placed in the signal_dec directory the signal ipa decrypted and unzipped.

It is known that with iOS you cannot do reproducible builds.

I would like to try to validate that the source repository when compiled has a high equivalence to the built iphone app.

Would you be able to generate the right build, and then decompile the iphone app and marry the two to see if there's high equivalence. This would help minimise doubt that there is a backdoor placed by signal and that signal is operating as intended.

Let me know what tools you need me to install first via brew.
```

A follow-up asked for a validation harness, so that the results could be checked instead of taken on trust: _"Is there a validation harness you can do to make sure you're not hallucinating on results."_ That request shaped the methodology. Every figure in this report comes from a script's output in `verify/out/`, never from the model's own judgement, and each analysis layer was tested against controls designed to fail.

// ---------- 2 ----------
= Inputs and their provenance

== The shipped app
#table(columns: (auto, 1fr),
  [Item], [Value],
  [App], [Signal 8.35.1, `CFBundleVersion` 1964],
  [Built by Signal with], [Xcode 27.1 (27A9275), iOS SDK 27.1, on Xcode Cloud (build paths `/Volumes/workspace/repository/...`)],
  [Embedded build metadata], [`BuildDetails.SignalCommit` = `4f019b8ba2d10b924d68b4b294bfceb05bde2aa4 Bump version to 8.35.1`, built 30 Oct 2026 17:11 UTC],
  [Encrypted IPA], [`signal.ipa` as downloaded from the App Store (SHA-256 withheld: the file embeds a FairPlay licence tied to the downloading account)],
  [Decrypted IPA], [`signal.decrypted.ipa` (SHA-256 withheld for the same reason; per-binary hashes are in `verify/out/provenance_ipa.txt`)],
  [Analysed copy], [`signal_dec/` (the decrypted IPA, unzipped)],
)

== Decryption with unfairplay
App Store binaries are FairPlay-encrypted, so the IPA was decrypted with *unfairplay* (#link("https://github.com/DrWhax/unfairplay")[github.com/DrWhax/unfairplay]). The analysis was given the *unzipped* decrypted app (`signal_dec/`), not the decrypted IPA itself. Because the decryption step sits between Apple's file and everything else, it was checked independently with `verify/validate_decryption.py`. The script reads both IPAs directly as zip archives:

#table(columns: (1.1fr, 1fr),
  [Check], [Result],
  [`.app` contents of the decrypted IPA vs `signal_dec/`], [#ok byte-identical (0 mismatching members)],
  [Mach-O binaries carrying FairPlay encryption], [22 of 22; `cryptid` 1 → 0],
  [Bytes changed by decryption *outside* the encrypted ranges], [#ok 0 (across all 22 binaries)],
  [Code-signature page hashes (SHA-256) on the *encrypted* IPA], [#ok 27,120 / 27,120 match: the input is intact as signed],
  [Decrypted pages that mismatch outside the encrypted range], [#ok exactly one per binary, the page holding the `cryptid` field (22/22)],
  [Non-binary files], [382 identical; `iTunesMetadata.plist` (purchase metadata, outside the app bundle) differs; 112 `SC_Info` licence files removed],
  [unfairplay's own manifest], [`complete: true`, `plaintext_verified: true` against pre-encryption hashes],
)

So decryption changed only the encrypted ranges and the `cryptid` flag. Everything else in the analysed copy is exactly as Apple signed it. One caveat remains. The code signature's page hashes cover the *encrypted* bytes, so they cannot by themselves prove the decrypted plaintext is correct. That proof comes from unfairplay's pre-encryption-hash check and, independently, from the result of this whole report: decrypted code that was wrong would not be byte-identical to code compiled from source.

// ---------- 3 ----------
= Methodology

== Reproducing Signal's build
The goal was to match Signal's Xcode Cloud release build as closely as possible:

- *Source:* a fresh clone from GitHub at tag `8.35.1.1964`. It resolves to the same commit, `4f019b8…`, as the commit the shipped app records.
- *Path:* a sparse APFS disk image mounted as `/Volumes/workspace`, so the source sits at `/Volumes/workspace/repository`, the same path as on Xcode Cloud. Build paths embedded in binaries therefore match.
- *Dependencies:* `make dependencies`, as Signal's `ci_scripts/ci_post_clone.sh` runs it. This gives the public `Signal-Pods` submodule at `6703bb87`, plus libsignal `v0.105.0` and RingRTC `v2.73.0`/WebRTC `8037a` prebuilt binaries, checked against the SHA-256 checksums pinned in the `Podfile`.
- *Toolchain:* Xcode 27.1 (27A9275), matching Signal's exact build. The Metal toolchain (27A266a) was a separate download.
- *Build:* `xcodebuild archive -scheme Signal -destination generic/platform=iOS` with the scheme's own Archive configuration, *App Store Release*. Code signing was turned off (`CODE_SIGNING_ALLOWED=NO`), since Signal's certificates are not available. The `production` feature-flag level is already committed at this tag for non-DEBUG builds.
- A clean build took about 6 minutes on this Mac (macOS 26.7, Apple silicon).

== Four builds
#table(columns: (auto, 1fr, auto),
  [Build], [Purpose], [Source],
  [A], [The candidate compared with the App Store app], [tag, unmodified],
  [B], [Noise control: identical source, clean rebuild], [tag, unmodified],
  [C], [Planted backdoor (noisy): key exfiltration to a URL, key weakening, and a call redirect], [tag + `verify/controls/planted_backdoor.patch`],
  [D], [Planted backdoor (subtle): one line changed in place, zeroing the last AES key byte; no new strings, symbols or calls, and no line-number shift], [tag + `verify/controls/planted_subtle.patch`],
)

== Comparison layers <layers>
Each pair (App Store app, build) is compared in layers, running from coarse to fine:

+ *Bundle inventory:* the SHA-256 of every file, grouped by kind (binary, plist, asset catalog, signature, resource).
+ *Binary features:* every string in the C-string, ObjC class/selector/type and Swift reflection sections, plus imported and exported symbols, linked libraries and section sizes, compared as multisets.
+ *Functions (assembly):* each binary's `__text` is split into functions using `LC_FUNCTION_STARTS` and disassembled with Apple's LLVM disassembler. Opcodes, registers and constants are kept exactly. Each *address* is replaced by what it points to: the imported symbol called through a stub, the ObjC selector of an `objc_msgSend` stub, the text of a loaded string, the referenced GOT symbol, or, for calls within the binary, the callee's own fingerprint. A redirected call or a swapped string therefore changes the fingerprint, while a mere shift in layout does not.
+ *Raw bytes:* the code signatures are removed with `codesign --remove-signature`, then every differing byte is assigned to the section or load command it falls in, so no difference goes unaccounted for. Raw `__text` hashes are taken with Apple's `segedit` and `shasum`, independently of any script written for this project.

*What was expected at the outset.* Before any build was made, the model told the user that this analysis "won't produce a bit-for-bit match. Signing, build paths, timestamps, link order and optimiser differences all get in the way, so the result is 'highly equivalent, with these differences explained.'" The original request also asked only for "high equivalence". On that expectation, nearly every byte of `__text` would differ because addresses shift, and only an address-independent comparison could show the code was the same. That is why the function layer was built, and why the plan also listed radare2 and Ghidra for diffing functions that did not match.

*What happened.* It turned out to be more straightforward than that. With the right build parameters (the same Xcode build, the Xcode Cloud build path `/Volumes/workspace/repository` and the scheme's own App Store Release configuration), the compiled code came out byte-identical. Build paths and timestamps did not leak into `__text`, and the only link-order effect was the GOT-slot ordering in the stubs. The raw-byte comparison alone is therefore the primary evidence, and radare2 and Ghidra were not needed. The function layer remains as an independent second method, a way to make sense of the GOT-ordering differences in the stubs, and a fallback for future versions that do not reproduce exactly.

== Guarding against a wrong result
Since a language model wrote both the harness and this report, the methodology assumes the model could be wrong and checks for it:

- *Results come only from scripts.* Figures in this report are copied from files in `verify/out/`, and `verify/compare_build.sh` re-creates them.
- *Independent cross-checks:* the string parser was checked against Apple's `segedit` (agreement on all ≈52,000 strings), and function boundaries against Apple's `dyld_info` (297/297 on the NSE). The most important result, byte-identical `__text`, relies only on Apple's tools.
- *Controls designed to fail:* an identical copy of the app (must match 100%), a tampered copy (must flag exactly the change), a rebuild of identical source (measures noise), and two planted backdoors (must be detected).
- *Determinism:* fingerprinting the same file twice gives identical output.

// ---------- 4 ----------
= Tooling written for this project
All scripts are in `verify/`, use only the Python standard library and Apple's command-line tools, and run with `python3 -I`.

#table(columns: (auto, 1fr),
  [Script], [Role],
  [`provenance.sh`], [Records tool versions, the source and Pods commits, and the SHA-256 of every shipped binary],
  [`inventory.py`, `compare_inventory.py`], [Per-file hash inventory of an `.app` and its diff],
  [`macho_features.py`], [Own Mach-O parser for string sections; Apple's `nm`/`otool` for symbols and libraries],
  [`crosscheck_strings.py`], [Checks the parser against Apple's `segedit`; refuses to continue on any disagreement],
  [`compare_features.py`], [Multiset comparison of features, listing every differing item],
  [`functions.py`], [Function splitting, disassembly, address-to-target resolution (via `dyld_info -fixups`) and two-pass fingerprints],
  [`compare_functions.py`], [Function matching by fingerprint; unmatched functions on both sides],
  [`bytediff.py`], [Removes signatures and assigns every differing byte to a section or load command],
  [`pngpixels.py`], [Decodes Apple CgBI PNGs and compares their pixels],
  [`validate_decryption.py`], [Checks a decrypted IPA against the encrypted original],
  [`compare_build.sh`, `summarise.py`], [Run every layer for a pair and summarise it],
)

*Defects found and fixed during the work.* Reporting these is part of the validation:
- The first build used `-configuration Release`, which does not exist in Signal's project. It was replaced with the scheme's *App Store Release*.
- The first string cross-check misread `otool` output and flagged every section. It was switched to `segedit`.
- A parser crash on register-plus-register `add` instructions.
- Export names containing spaces (ObjC methods such as `+[OWSAES256Key supportsSecureCoding]`) were split in half. Fixing this changed no result, because both sides had been split the same way.
- The assumption that code-signature hashes cover the plaintext was wrong. They cover the encrypted bytes, and the decryption check was corrected to match.
- The function layer still produces false positives when a binary's layout shifts (@limits).

// ---------- 5 ----------
= Results

== First-party binaries: App Store app vs build A
#table(columns: (1fr, auto, auto, auto, auto),
  align: (left, right, right, left, left),
  [Binary], [Functions], [Instructions], [`__text` bytes], [Feature layers],
  [Signal], [50,566 / 50,566], [2,652,940], [#ok identical], [#ok all identical],
  [SignalServiceKit], [82,839 / 82,839], [4,267,966], [#ok identical], [#ok all identical],
  [SignalUI], [17,175 / 17,175], [735,432], [#ok identical], [#ok all identical],
  [SignalNSE], [297 / 297], [9,366], [#ok identical], [#ok all identical],
  [SignalShareExtension], [647 / 647], [23,419], [#ok identical], [#ok all identical],
  [*Total*], [*151,524*], [*7,689,123*], [], [],
)
"Feature layers" covers, for example in `Signal`: 16,273 C strings, 1,060 ObjC class names, 5,746 selectors, 9,695 Swift field names, 8,209 imports and 100 linked libraries. Every one of these is identical in both builds, with no additions and no removals.

== Accounting for every differing byte <bytes>
With signatures removed, every pair of binaries has exactly the same size. The bytes that still differ are:

#table(columns: (auto, auto, 1fr),
  [Binary], [Bytes], [Cause],
  [SignalServiceKit\ SignalNSE\ SignalShareExtension], [1–2], [The `__LINKEDIT` vmsize. It was sized for Apple's signature (for example, 4,209,328 B of link data + 497,408 B of signature, rounded up to 16 KB = `0x480000`). Ours is sized for no signature (`0x404000`). This is caused by signing alone.],
  [Signal], [1,710], [The same vmsize byte, plus `LC_UUID` (16 B), plus 1,694 bytes in `__stubs`/`__objc_stubs`. The linker made two GOT slots, both bound to `libobjc/_objc_msgSend` in *both* builds (checked with `dyld_info`), and pointed the stubs at them in the opposite order. The UUID depends on these bytes.],
  [SignalUI], [1,182], [The same pattern: two `_objc_msgSend` slots swapped, 1,165 stub bytes, plus the UUID],
)
*The noise control confirms this.* In build B, the GOT-slot order happened to match Apple's for `Signal`: *IPA `Signal` vs build B `Signal` differs by exactly 1 byte (the signature-size field)*. Meanwhile `SignalServiceKit` flipped order in B, and builds A and B differ from each other by the same stub pattern. The ordering is therefore linker nondeterminism between builds of identical source, not something added to the App Store build.

== Third-party frameworks
#block(breakable: false)[#table(columns: (1fr, 1fr),
  [Frameworks], [Result after removing signatures],
  [LibSignalClient, SignalRingRTC, SQLCipher, MobileCoin, LibMobileCoin, GRDB, SwiftProtobuf, CocoaLumberjack, Logging, BonMot, Lottie, PureLayout, SDWebImage, SDWebImageWebPCoder, libPhoneNumber, libwebp], [#ok identical except the signature-size byte (1–2 bytes)],
  [WebRTC], [#ok identical except the signature-size byte, after `lipo -thin arm64`. Signal's prebuilt is a single-architecture "fat" binary, which App Store thinning unwraps. Both have UUID `4C4C44B7-5555-3144-A187-CBA7B54C9452`, matching the RingRTC prebuild Signal published],
)]
LibSignalClient (the Signal Protocol implementation), RingRTC/WebRTC and MobileCoin come as *prebuilt binaries* pinned by checksum. This shows the App Store app contains exactly those published prebuilds. @deps rebuilds the prebuilds themselves from their own source.

== Prebuilt native libraries rebuilt from source <deps>
Four native libraries reach the app as prebuilt binaries, not compiled during the app build. Each was rebuilt from its own public source and compared with the prebuild, member by member for static libraries (`verify/ar_compare.py`) and section by section for WebRTC. The recipe for each was recovered from the project's CI workflow and logs, or from the toolchain versions and paths recorded inside the prebuild. Where a library records absolute paths (in debug information), the build used those same paths. The scripts are in `verify/deps/`, and the outputs are in `versions/8.35.1.1964/out/deps/`.

#table(
  columns: (auto, 1fr, auto),
  table.header([Library], [Source and recipe], [Result]),
  [libsignal \ `libsignal_ffi.a` \ `v0.105.0`], [Tag `v0.105.0` of `signalapp/libsignal`. Signal's public CI run (7 Oct 2026) shows it built the pinned archive (`556a8241…`), with Rust 1.98.1, Xcode 16.4 and `swift/build_ffi.sh --release`. Rebuilt the same way at the runner's paths (`/Users/runner/work/libsignal/libsignal`, `/Applications/Xcode_16.4.app`).], [#ok byte-identical \ (803 of 803 members, SHA-256 `296840c5…`)],
  [RingRTC \ `libringrtc.a` \ `v2.73.0`], [Tag `v2.73.0` of `signalapp/ringrtc`; `cargo rustc --crate-type staticlib` as `bin/build-ios` runs it, with Rust 1.97.1 and Xcode 26.2 (both recorded in the prebuild), and `WEBRTC_VERSION=8037a` from `config/version.properties` (compiled into the library).], [#ok byte-identical \ (579 of 579 members, `f9614059…`)],
  [WebRTC \ `WebRTC.framework` \ `8037a`], [Tag `8037a` (`e47f2d8`) of Signal's fork `signalapp/webrtc`, synced by `gclient` with every dependency pinned by its `DEPS` file, and built by RingRTC v2.73.0's `bin/build-ios --webrtc-only` with Chromium's pinned clang and the Xcode 26.1.1 SDK (both recorded in the prebuild's `build_env.txt`).], [#ok identical except the 8-byte `LC_UUID` \ (`__text` byte-identical, 7,439,384 bytes)],
  [libmobilecoin \ `libmobilecoin.a` \ `6.0.2`], [Tag `signal/6.0.2` of `signalapp/libmobilecoin-ios-artifacts` (MobileCoin `v6.0.2`, `fe8017c`). Built on a developer's Mac, not CI: the prebuild records Rust `nightly-2023-10-01`, Xcode 14.2 at `/Applications/Xcode.app`, and source and Cargo paths under `/Users/signal`. Rebuilt with those, plus CMake 3.29.3 patched by the repository's `tools/patch-cmake.sh`.], [#ok byte-identical \ (602 of 602 members, `ebfa6710…`)],
)

Notes on the recipes:
- *WebRTC's UUID.* The linker derives it from build inputs that are then stripped (the framework's debug symbols are deleted). Every other byte of the 8.67 MB binary matches. The same kind of difference appears in the app's own binaries (@bytes).
- *WebRTC's build script.* The prebuild's `build_env.txt` names an unpublished RingRTC commit (`c92b159`, on a branch for WebRTC m154) as the build script. RingRTC's public v2.73.0 scripts produced the same code, so that commit made no difference to the output.
- *libmobilecoin's CMake.* The exact CMake version on the developer's machine isn't recorded. CMake 3.29.3, current when the artifact was committed (June 2024), reproduced every object exactly, including the mbedTLS objects built through CMake.
- *Shared with 8.36.* Signal 8.36 uses the same RingRTC, WebRTC and libmobilecoin builds, so these results cover it too. 8.36's newer libsignal (`v0.106.1`) was rebuilt separately and is also byte-identical.

== Non-code files
- *Plists (33 differ):* `BuildMachineOSBuild` (Xcode Cloud `26A434` vs local `25G229`), `CFBundleVersion` (`1964` vs `0`; Xcode Cloud sets it at export), `BuildDetails` date and timestamp, and `DTAppStoreToolsBuild` (added by App Store processing). No other keys differ.
- *Asset catalogs:* identical rendition sets (2,891 and 2,529 renditions), produced by the same Xcode build. Only the 73 app-icon renditions differ. Their names include a random UUID, process ID and timestamp from `actool`, and the two loose icon PNGs differ by at most 1/255 in one channel, in under 1% of pixels (icon-resizing rounding). Icons are images with no executable content.
- *Code signatures:* the 62 `_CodeSignature` files exist only in the signed App Store app.
- Every other file is byte-identical (280 of 339 shared files are identical; each of the remaining 59 is explained above).

== Controls
#table(columns: (auto, 1fr, auto),
  [Control], [Outcome], [Pass],
  [Identical copy], [401/401 files; 50,566/50,566 functions], [#ok],
  [Tampered copy (1 byte appended, 1 file added)], [Flags exactly that file and the added file], [#ok],
  [Build B, identical source], [`__text` identical in all 5 binaries; only GOT-order noise, which changes between builds], [#ok],
  [Build C: key exfiltration], [New strings `https://planted-control.invalid/collect`, `planted-backdoor-control`; new selector `sharedSession`; changed `__text`], [#ok],
  [Build C: call redirect in `Signal`], [Caught as a changed caller (`0x10048d5ec`). Swift inlined the new callee, so it was a body change, not a pure target swap], [#ok],
  [Build D: one-line key weakening], [`SignalServiceKit` `__text` hash changed, the other 4 binaries unchanged; *no* string, import or metadata difference (as expected); the changed function is identified and readable: `count − 1`, a `Data` subscript set to `0`, then `_crypt(op: kCCEncrypt)`], [#ok],
)
In build C, most of the 652 flagged `SignalServiceKit` functions changed for a genuine reason: inserting 14 lines shifts the source line numbers compiled into assertions (`OWSAssertionError` records `#line`). 44 of the 51 changed constants are exactly +14. The layers are therefore *more* sensitive than strictly necessary.

// ---------- 6 ----------
= Comparison with Signal Android's reproducible builds
Signal Android publishes a reproducible-build procedure (#link("https://github.com/signalapp/Signal-Android/blob/main/reproducible-builds/README.md")[`reproducible-builds/README.md`]). Its build environment is a Docker image from the repository's `Dockerfile`, built from the release's git tag. The user builds the Play bundle in Docker, uses `bundletool` to generate the APKs the Play Store would install on their device, pulls the installed APKs with `adb`, and compares them with `apkdiff.py`. That tool ignores "signing information" and "extra harmless metadata added by the Play Store". Success means every pair (base, ABI and density splits) prints "APKs match!".

#table(columns: (auto, 1fr, 1fr),
  [], [Signal Android (official)], [This iOS analysis],
  [Build environment], [Docker image defined in the repo, maintained by Signal], [Xcode version pinned by `.xcode-version`; Xcode Cloud path recreated by hand; not containerised (macOS/Xcode cannot be)],
  [Getting the shipped artefact], [`adb pull` of the installed APKs; no decryption needed], [FairPlay-encrypted IPA, decrypted with a third-party tool (unfairplay), then validated],
  [Comparison], [`apkdiff.py`: archive contents compared, signatures and Play Store metadata ignored], [Custom multi-layer harness; signature removed; every remaining byte accounted for],
  [Result format], [Binary verdict: "APKs match!"], [Byte-identical code, plus an itemised list of explained non-code differences],
  [Who can do it], [Anyone with Docker; documented and supported], [Needs a Mac, the exact Xcode build, and an iOS decryption step; not supported by Signal],
  [Re-verification], [Every release, by anyone], [This one release; scripts in `verify/` can be re-run for others],
)

The two reach a comparable standard by different routes. Android's procedure is official, repeatable and easy for anyone to follow, but its verdict is binary and relies on `apkdiff.py`'s list of ignored differences. This iOS analysis is improvised and much harder to repeat. However, for the code it arrived at the same strong result, byte-identical compiled code, and it explains every byte that is not identical instead of leaving it out. "iOS builds cannot be reproduced" turned out not to apply to the code: with the same Xcode build and build path, Signal's iOS code reproduced exactly. What could not be reproduced is Apple's signature, FairPlay encryption and App Store post-processing, and those were handled by removing or reversing them and checking the result.

// ---------- 7 ----------
= Limitations <limits>
+ *Trust in the source is a separate question.* This work shows the App Store binary equals what the public source produces. A backdoor *committed to the public repository* would reproduce exactly and pass every check here. Ruling that out needs a source review, focusing on code paths that handle keys, plaintext and networking.
+ *Prebuilt dependencies.* These were first only checked against their published checksums. They have since been rebuilt from their own source and match (@deps). What remains trusted is the toolchain: Apple's Xcode compilers, the Rust toolchains from rustup, and Chromium's prebuilt clang. A compromised compiler would reproduce its own output. Ruling that out ("trusting trust") is beyond this work.
+ *Private Pods repository.* `Scripts/setup_private_pods` can switch the build to `Signal-Pods-Private`. Whether Signal's release builds do so is an Xcode Cloud setting that can't be inspected. For this release it makes no difference: every framework built from Pods matched the public Pods exactly.
+ *One release, one copy.* The result covers 8.35.1 (1964), this downloaded copy and one device class (App Store thinning). Other versions, other thinned variants, or another user's download were not checked.
+ *Outside the IPA.* What iOS does at install or run time, and code loaded at run time (if any), are outside what a static comparison can see. Server-side behaviour is out of scope.
+ *Decryption trust.* The decrypted plaintext relies on a third-party tool. It is backed by that tool's plaintext-hash verification and, more strongly, by the plaintext being byte-identical to independently compiled code, which a faulty decryption could not plausibly produce.
+ *Function-layer false positives.* When layout shifts (builds C and D), the function layer flags extra functions. These come from LLVM's machine outliner, which passes page addresses in registers between functions; the per-function tracker cannot resolve them. In build D, 13 of 14 directly changed functions were such false positives, each a single 16-byte constant load shifted by `+0x140`. This affects *locating* changes in a shifted binary, not *detecting* them, and it cannot affect the main result: the A comparison had no shift, and its match is backed by byte-identical `__text`.
+ *Not every flagged item was traced.* In build C, 7 of the 51 changed constants and one register-allocation change in build D (`0xbed94c`) were not individually traced to a source line.

// ---------- 8 ----------
= What the model can conclude
I'm Claude, the model that did this analysis and wrote this report, and I want to state my conclusions carefully. I wrote the tools that produced the evidence, so the strongest claims below rest on checks that don't depend on them: Apple's `segedit`/`shasum` hashes and the planted controls.

*Supported by the evidence:*
- The compiled code shipped in Signal iOS 8.35.1 (1964) for Signal's own five binaries is *byte-for-byte* the code produced by compiling the public tag `8.35.1.1964` with Xcode 27.1 (27A9275).
- Nothing was added, removed or altered in those binaries apart from a code signature, its size field, and a linker GOT-slot ordering that varies between identical builds.
- The bundled third-party frameworks are exactly the versions the public repository pins. The four that arrive as prebuilt binaries (libsignal, RingRTC, WebRTC, libmobilecoin) were also rebuilt from their own public source and match, so no part of the app's compiled code is an unexplained binary.
- The harness is capable of catching a hidden change: a single-line key weakening, with no new strings or symbols, was detected and traced to the function that contains it.

*Therefore,* for this release, a backdoor *added by Signal (or anyone in its build pipeline) after the public source* is ruled out to a very high degree of confidence. The App Store app runs the code in the public repository.

*Not supported:* this says nothing about whether the public source contains a backdoor or a vulnerability, nothing about server behaviour, and nothing about other releases. "Operating as intended" holds in the narrow sense that the shipped app matches its public source. Whether that source does what Signal says it does is a separate review.

// ---------- 9 ----------
= Cost and effort
The figures below were reported by Claude Code's `/cost` command at the end of the session, before this section was added. They cover the whole conversation: planning, harness development, the four builds, the analysis and the report.

#table(columns: (auto, 1fr),
  [Measure], [Value],
  [Total cost], [*\$9.22* (USD)],
  [Main model, `claude-opus-5-5`], [1.6k input · 139.5k output · 22.0M cache read · 251.6k cache write tokens (\$9.22)],
  [Helper model, `claude-haiku-5-5`], [10.0k input · 1.7k output tokens (\$0.0019)],
  [Prompt cache], [133 requests; 99% of input tokens served from cache; no misses],
  [API time], [25 min 20 s],
  [Wall-clock time], [1 h 23 min 46 s (mostly Xcode builds and user actions such as installing Xcode)],
  [Code written], [1,592 lines added, 147 removed (the `verify/` harness and this report)],
)
Most of the cost is in the cache reads. Each turn sends the whole conversation back as context, and long tool outputs such as build logs and comparison tables add to that. The Xcode builds (about 6 minutes each, four in total, plus two failed attempts) used local compute only and no tokens.

// ---------- 10 ----------
= Reproducing these results
```sh
# 1. Source at the Xcode Cloud path
hdiutil create -size 150g -type SPARSE -fs APFS -volname workspace workspace.sparseimage
hdiutil attach workspace.sparseimage -nobrowse
git clone https://github.com/signalapp/Signal-iOS.git /Volumes/workspace/repository
cd /Volumes/workspace/repository && git checkout 8.35.1.1964
Scripts/check_xcode_version.py && make dependencies
xcodebuild -downloadComponent MetalToolchain

# 2. Build (scheme's App Store Release configuration, unsigned)
xcodebuild archive -workspace Signal.xcworkspace -scheme Signal \
  -destination 'generic/platform=iOS' -derivedDataPath /Volumes/workspace/DerivedData \
  -archivePath /Volumes/workspace/build-A.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

# 3. Compare (from this repository's root, with the decrypted app unzipped to signal_dec/)
verify/compare_build.sh signal_dec/Payload/Signal.app \
  /Volumes/workspace/build-A.xcarchive/Products/Applications/Signal.app verify/out/ipa_vs_A
python3 -I verify/summarise.py verify/out/ipa_vs_A
python3 -I verify/bytediff.py <ipa binary> <built binary> out.json
python3 -I verify/validate_decryption.py signal.ipa signal.decrypted.ipa out.json signal_dec/Payload/Signal.app
```
Outputs (moved from `verify/out/` to `versions/8.35.1.1964/out/`, with the decrypted app in `versions/8.35.1.1964/signal_dec/`): `ipa_vs_A/` (main comparison and byte accounting), `controls/` (identity, tamper, built-twice, planted C and D), `decryption_validation.json`, `provenance_ipa.txt`, and `deps/` (prebuilt-library rebuilds). Controls: `verify/controls/*.patch`.

Prebuilt libraries (@deps): `verify/deps/build_libsignal.sh v0.105.0`, `build_ringrtc.sh v2.73.0`, `build_webrtc.sh` and `build_libmobilecoin.sh signal/6.0.2`, each followed by `verify/ar_compare.py <prebuilt.a> <built.a>`. Each script lists its prerequisites (Xcode version and path, and the `/Users/runner` or `/Users/signal` directory).

// ---------- changelog ----------
= Changelog
#table(
  columns: (auto, 1fr),
  table.header([*Date*], [*Change*]),
  [7 November 2026], [First published version.],
  [7 November 2026], [*Added* to @layers: what was expected at the outset (no bit-for-bit match, hence the function layer), and what happened (the right build parameters produced byte-identical code, making the raw-byte comparison the primary evidence). *Added* this changelog. Nothing deleted.],
  [8 November 2026], [*Added* @deps: the four prebuilt native libraries (libsignal, RingRTC, WebRTC, libmobilecoin) rebuilt from source and matched; an update note in the summary; a conclusion bullet; dependency scripts in Reproducing. *Changed* the prebuilt-dependencies limitation, which previously said they were checked only against checksums, and the sentence in the third-party section that pointed to it. *Changed* the output paths in Reproducing, which moved to `versions/8.35.1.1964/out/`.],
)
