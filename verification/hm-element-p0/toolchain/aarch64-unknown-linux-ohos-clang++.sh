#!/bin/sh
exec "${OHOS_SDK_NATIVE:?set OHOS_SDK_NATIVE}/llvm/bin/clang++" \
  -target aarch64-linux-ohos \
  --sysroot="${OHOS_SDK_NATIVE}/sysroot" \
  -D__MUSL__ \
  "$@"
