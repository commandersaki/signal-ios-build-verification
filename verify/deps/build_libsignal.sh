#!/bin/bash
# Rebuild libsignal_ffi.a (aarch64-apple-ios) exactly as libsignal's "Release - iOS" GitHub workflow does.
# Paths, toolchain and Xcode match the CI runner, because the C objects record absolute paths.
# Prerequisites: /Users/runner owned by you; Xcode 16.4 (16F6) at /Applications/Xcode_16.4.app; rustup.
# Usage: build_libsignal.sh <tag, e.g. v0.105.0>
# Output: /Users/runner/work/libsignal/libsignal/target/aarch64-apple-ios/release/libsignal_ffi.a
set -euo pipefail
TAG="$1"
export HOME=/Users/runner RUSTUP_HOME=/Users/runner/.rustup CARGO_HOME=/Users/runner/.cargo
export DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer CARGO_TERM_COLOR=always
rm -rf /Users/runner/work/libsignal/libsignal && mkdir -p /Users/runner/work/libsignal
git clone -q --depth 1 --branch "$TAG" --recurse-submodules --shallow-submodules \
  https://github.com/signalapp/libsignal.git /Users/runner/work/libsignal/libsignal
cd /Users/runner/work/libsignal/libsignal
rustup toolchain install "$(cat rust-toolchain)" --profile minimal \
  --target x86_64-apple-ios,aarch64-apple-ios,aarch64-apple-ios-sim --component rust-src
CARGO_BUILD_TARGET=aarch64-apple-ios swift/build_ffi.sh --release
