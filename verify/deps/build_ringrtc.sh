#!/bin/bash
# Rebuild libringrtc.a (aarch64-apple-ios) as RingRTC's bin/build-ios does for the iOS artifact.
# WEBRTC_VERSION must be set from config/version.properties (build-ios sources config/version.sh);
# it is compiled into the library.
# Prerequisites: /Users/runner owned by you; Xcode 26.2 (17C52) at /Applications/Xcode_26.2.app; rustup.
# Usage: build_ringrtc.sh <tag, e.g. v2.73.0>
# Output: /Users/runner/work/ringrtc/ringrtc/out/build/aarch64-apple-ios/release/libringrtc.a
set -euo pipefail
TAG="$1"
export HOME=/Users/runner RUSTUP_HOME=/Users/runner/.rustup CARGO_HOME=/Users/runner/.cargo
export DEVELOPER_DIR=/Applications/Xcode_26.2.app/Contents/Developer CARGO_TERM_COLOR=always
R=/Users/runner/work/ringrtc/ringrtc
[ -d "$R" ] || git clone -q --depth 1 --branch "$TAG" https://github.com/signalapp/ringrtc.git "$R"
cd "$R"
rustup toolchain install "$(cat rust-toolchain)" --profile minimal \
  --target x86_64-apple-ios,aarch64-apple-ios,aarch64-apple-ios-sim --component rust-src
export WEBRTC_VERSION="$(cd config && bash -c '. ./version.sh >/dev/null && echo "$WEBRTC_VERSION"')"
export IPHONEOS_DEPLOYMENT_TARGET=14.0
cd src/rust
CARGO_TARGET_DIR="$R/out/build" cargo rustc --target aarch64-apple-ios --release --crate-type staticlib
