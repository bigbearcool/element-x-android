#!/bin/sh
# Re-run the locked matrix-sdk-ffi build for aarch64-unknown-linux-ohos.
# Requires the public OpenHarmony Linux native SDK unpacked so that
# $OHOS_SDK_NATIVE contains llvm/ and sysroot/. This script does not
# fetch newer crates: cargo is invoked with --locked.
set -u
NATIVE="${OHOS_SDK_NATIVE:?set OHOS_SDK_NATIVE}"
SDK_SRC="${MATRIX_RUST_SDK_SRC:?set MATRIX_RUST_SDK_SRC to commit 3ff03638028fd9abf58203153722b94b4293a87a}"
ROOT="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
export CC_aarch64_unknown_linux_ohos="$ROOT/toolchain/aarch64-unknown-linux-ohos-clang.sh"
export CXX_aarch64_unknown_linux_ohos="$ROOT/toolchain/aarch64-unknown-linux-ohos-clang++.sh"
export AR_aarch64_unknown_linux_ohos="$NATIVE/llvm/bin/llvm-ar"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_LINKER="$CC_aarch64_unknown_linux_ohos"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_AR="$AR_aarch64_unknown_linux_ohos"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
export CARGO_PROFILE_RELEASE_LTO=false
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16
export CARGO_PROFILE_RELEASE_OPT_LEVEL=2
cd "$SDK_SRC"
cargo build --locked --release --target aarch64-unknown-linux-ohos \
  -p matrix-sdk-ffi \
  --features sentry,experimental-x509-identity-verification
