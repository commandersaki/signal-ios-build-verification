#!/bin/bash
# Rebuild WebRTC.xcframework as RingRTC's "Build WebRTC Artifacts" workflow does
# (bin/build-webrtc.py --target ios --release), minus its sudo steps (Xcode is chosen with DEVELOPER_DIR).
# Uses the RingRTC checkout from build_ringrtc.sh; gclient syncs signalapp/webrtc at config/version.properties.
# Prerequisites: Xcode 26.1.1 (17B100) at /Applications/Xcode_26.1.1.app; /usr/local/lib must exist; ~15 GB.
# Output: /Users/runner/work/ringrtc/ringrtc/out/release/WebRTC.xcframework
set -euo pipefail
export HOME=/Users/runner RUSTUP_HOME=/Users/runner/.rustup CARGO_HOME=/Users/runner/.cargo
export DEVELOPER_DIR=/Applications/Xcode_26.1.1.app/Contents/Developer
R=/Users/runner/work/ringrtc/ringrtc
cd "$R"
[ -d out/depot_tools ] || { mkdir -p out && git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git out/depot_tools; }
export PATH="$R/out/depot_tools:$PATH"
bin/prepare-workspace ios
bin/build-ios --webrtc-only --archive-webrtc --release
