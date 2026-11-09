#!/bin/sh
exec "/tmp/hm-element-p0/sdk/unpack/native/native/llvm/bin/clang" \
  -target aarch64-linux-ohos \
  --sysroot="/tmp/hm-element-p0/sdk/unpack/native/native/sysroot" \
  -D__MUSL__ \
  "$@"
