#!/bin/sh
# OHOS_SDK_NATIVE is the directory that contains llvm/ and sysroot/.
# This run used OpenHarmony public SDK 7.0-Beta1, package
# native-linux-x64-26.0.0.25-Beta.zip, unpacked so that llvm/ and sysroot/ are direct children.
exec "${OHOS_SDK_NATIVE:?set OHOS_SDK_NATIVE}/llvm/bin/clang" \
  -target aarch64-linux-ohos \
  --sysroot="${OHOS_SDK_NATIVE}/sysroot" \
  -D__MUSL__ \
  "$@"
