#!/bin/bash
# Rebuild libmobilecoin.a (aarch64-apple-ios) from signalapp/libmobilecoin-ios-artifacts, as its Makefile does.
# The 6.0.2 artifact was built on a developer Mac: source under /Users/signal/work, Rust managed by asdf
# (CARGO_HOME=RUSTUP_HOME=/Users/signal/.asdf/installs/rust/stable), Xcode 14.2 at /Applications/Xcode.app,
# and a CMake 3.x patched by tools/patch-cmake.sh. Those paths are recorded in the library, so they are recreated.
# Xcode 14.2 is temporarily renamed to /Applications/Xcode.app; the original names are restored on exit.
# Prerequisites: /Users/signal owned by you; Xcode 14.2 (14C18) at /Applications/Xcode-14.2.0.app;
#   CMake 3.29.3 (e.g. `pip install cmake==3.29.3` in a venv) with patch-cmake.sh's edit applied to its
#   Modules/Platform/iOS-Initialize.cmake, its bin directory given as CMAKE_BIN; rustup.
# Usage: CMAKE_BIN=<dir> build_libmobilecoin.sh <tag, e.g. signal/6.0.2>
# Output: /Users/signal/work/libmobilecoin-ios-artifacts/libmobilecoin/target/aarch64-apple-ios/mobile-release/libmobilecoin.a
set -euo pipefail
TAG="$1"; : "${CMAKE_BIN:?set CMAKE_BIN to the patched CMake 3.29.3 bin directory}"
S=/Users/signal/work/libmobilecoin-ios-artifacts
[ -d "$S" ] || git clone -q --branch "$TAG" https://github.com/signalapp/libmobilecoin-ios-artifacts.git "$S"
git -C "$S" -c submodule.Artifacts.update=none submodule update --init --recursive Vendor/mobilecoin
restore() {
  [ -d /Applications/Xcode-saved.app ] || return 0
  mv /Applications/Xcode.app /Applications/Xcode-14.2.0.app && mv /Applications/Xcode-saved.app /Applications/Xcode.app
}
trap restore EXIT
mv /Applications/Xcode.app /Applications/Xcode-saved.app
mv /Applications/Xcode-14.2.0.app /Applications/Xcode.app
export HOME=/Users/signal RUSTUP_HOME=/Users/signal/.asdf/installs/rust/stable CARGO_HOME=/Users/signal/.asdf/installs/rust/stable
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer SGX_MODE=HW IAS_MODE=PROD PATH="$CMAKE_BIN:$PATH"
unset CARGO_BUILD_FLAGS CARGO_TARGET_DIR CARGO_PROFILE
cd "$S/libmobilecoin"
rustup toolchain install "$(cat rust-toolchain)" --profile minimal --target aarch64-apple-ios --component rust-src,llvm-tools-preview
CFLAGS="-DPB_NO_PACKED_STRUCTS=1" CXXFLAGS="-DPB_NO_PACKED_STRUCTS=1" IPHONEOS_DEPLOYMENT_TARGET="13.0" \
  cargo build --package libmobilecoin --target aarch64-apple-ios --lib -Z avoid-dev-deps -Z unstable-options --profile mobile-release
