#!/bin/bash
set -u
export PATH="/usr/local/cargo/bin:$PATH"
NATIVE=/tmp/hm-element-p0/sdk/unpack/native/native
export CC_aarch64_unknown_linux_ohos=/tmp/hm-element-p0/toolchain/aarch64-unknown-linux-ohos-clang.sh
export CXX_aarch64_unknown_linux_ohos=/tmp/hm-element-p0/toolchain/aarch64-unknown-linux-ohos-clang++.sh
export AR_aarch64_unknown_linux_ohos="$NATIVE/llvm/bin/llvm-ar"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_LINKER="$CC_aarch64_unknown_linux_ohos"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_AR="$AR_aarch64_unknown_linux_ohos"
READELF="$NATIVE/llvm/bin/llvm-readelf"
NM="$NATIVE/llvm/bin/llvm-nm"
LOG=/tmp/hm-element-p0/logs
TARGET=aarch64-unknown-linux-ohos

summarize() {
  local so="$1"
  if [ -f "$so" ]; then
    file "$so"
    "$READELF" -h "$so" | rg 'Machine|Class|Type'
    echo '-- needed --'
    "$READELF" -d "$so" | rg 'NEEDED' || true
    echo '-- exports --'
    "$NM" -D "$so" | rg 'hm_poc| T ' | head -20 || true
  else
    echo "MISSING $so"
  fi
}

echo "===== native-deps $(date -u +%H:%M:%S) ====="
cd /tmp/hm-element-p0/poc/native-deps
if cargo build --target "$TARGET" --release > "$LOG/07-native-deps.log" 2>&1; then
  echo NATIVE_DEPS_EXIT:0
else
  echo NATIVE_DEPS_EXIT:$?
fi
tail -25 "$LOG/07-native-deps.log"
summarize target/$TARGET/release/libohos_native_deps.a

echo "===== tls-aws-lc $(date -u +%H:%M:%S) ====="
cd /tmp/hm-element-p0/poc/tls-aws-lc
if cargo build --target "$TARGET" --release > "$LOG/08-tls-aws-lc.log" 2>&1; then
  echo TLS_EXIT:0
else
  echo TLS_EXIT:$?
fi
tail -40 "$LOG/08-tls-aws-lc.log"

echo "===== sqlcipher probe $(date -u +%H:%M:%S) ====="
cd /tmp/hm-element-p0/poc/sqlcipher-probe
if cargo build --target "$TARGET" --release > "$LOG/09-sqlcipher.log" 2>&1; then
  echo SQLCIPHER_EXIT:0
else
  echo SQLCIPHER_EXIT:$?
fi
tail -30 "$LOG/09-sqlcipher.log"

echo "===== napi rust staticlib $(date -u +%H:%M:%S) ====="
cd /tmp/hm-element-p0/poc/napi/ruststat
if cargo build --target "$TARGET" --release > "$LOG/10-napi-rust.log" 2>&1; then
  echo NAPI_RUST_EXIT:0
else
  echo NAPI_RUST_EXIT:$?
fi
tail -15 "$LOG/10-napi-rust.log"

echo "===== napi c++ link $(date -u +%H:%M:%S) ====="
cd /tmp/hm-element-p0/poc/napi
if "$CXX_aarch64_unknown_linux_ohos" \
  -fPIC -shared \
  napi_async.cpp \
  -I"$NATIVE/sysroot/usr/include" \
  /tmp/hm-element-p0/poc/napi/ruststat/target/$TARGET/release/libhm_poc_napi_rust.a \
  -lace_napi.z \
  -o /tmp/hm-element-p0/poc/napi/libhm_poc.so \
  > "$LOG/11-napi-cpp.log" 2>&1; then
  echo NAPI_CPP_EXIT:0
else
  echo NAPI_CPP_EXIT:$?
fi
cat "$LOG/11-napi-cpp.log"
summarize /tmp/hm-element-p0/poc/napi/libhm_poc.so
echo "===== BUILD SCRIPT END $(date -u +%H:%M:%S) ====="
