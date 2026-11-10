#!/bin/sh
# Cloud-side contract check for the diagnostic native module.
# This does not load the .so in ArkTS and does not replace a device run.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ENTRY=$ROOT/hap-diag/entry
DIAG=$ENTRY/libs/arm64-v8a/libhm_sdk_diag.so
BRIDGE=$ENTRY/libs/arm64-v8a/libohos_min_bridge.so
PKG=$ENTRY/oh-package.json5
TYPES=$ENTRY/src/main/cpp/types/libhm_sdk_diag/oh-package.json5
fail=0
say() { printf '%s\n' "$1"; }

need_tool() {
  for c in "$@"; do
    if command -v "$c" >/dev/null 2>&1; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 1
}
READELF=$(need_tool llvm-readelf readelf) || { echo "need llvm-readelf or readelf" >&2; exit 2; }
NM=$(need_tool llvm-nm nm) || { echo "need llvm-nm or nm" >&2; exit 2; }

say "CLOUD_CHECK_ONLY device ArkTS import is not executed here"
if [ ! -f "$PKG" ]; then
  say "FAIL missing $PKG"
  fail=1
else
  python3 - "$PKG" << 'PY' || fail=1
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
ok = '"libhm_sdk_diag.so"' in text and "file:./src/main/cpp/types/libhm_sdk_diag" in text
print("PASS entry dependency" if ok else "FAIL entry/oh-package.json5 does not declare libhm_sdk_diag.so file dependency")
sys.exit(0 if ok else 1)
PY
fi
if [ ! -f "$TYPES" ]; then
  say "FAIL missing types package"
  fail=1
else
  python3 - "$TYPES" << 'PY' || fail=1
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
ok = '"name"' in text and "libhm_sdk_diag.so" in text and "Index.d.ts" in text or "index.d.ts" in text
print("PASS types package name" if '"libhm_sdk_diag.so"' in text else "FAIL types package name")
sys.exit(0 if '"libhm_sdk_diag.so"' in text else 1)
PY
fi
if ! "$NM" -D "$DIAG" | awk '$2=="T" && $3=="hm_sdk_diag_register" {found=1} END {exit found?0:1}'; then
  say "FAIL constructor hm_sdk_diag_register is not exported"
  fail=1
else
  say "PASS constructor hm_sdk_diag_register"
fi
if ! strings "$DIAG" | grep -Fxq hm_sdk_diag; then
  say "FAIL nm_modname string hm_sdk_diag missing"
  fail=1
else
  say "PASS nm_modname string hm_sdk_diag"
fi
needed=$("$READELF" -d "$DIAG" | awk '/NEEDED/ {print $NF}' | tr -d '[]')
say "NEEDED $needed"
for lib in libohos_min_bridge.so libace_napi.z.so libc.so; do
  if printf '%s\n' "$needed" | grep -Fxq "$lib"; then
    say "PASS NEEDED $lib"
  else
    say "FAIL missing NEEDED $lib"
    fail=1
  fi
done
if printf '%s\n' "$needed" | grep -Fxq libc++_shared.so; then
  say "FAIL diag so still needs libc++_shared.so and this package does not ship one"
  fail=1
else
  say "PASS diag so does not need libc++_shared.so"
fi
if [ ! -f "$BRIDGE" ]; then
  say "FAIL missing bridge so"
  fail=1
else
  bridge_needed=$("$READELF" -d "$BRIDGE" | awk '/NEEDED/ {print $NF}' | tr -d '[]')
  if printf '%s\n' "$bridge_needed" | grep -Fxq libmatrix_sdk_ffi.so; then
    say "FAIL bridge unexpectedly needs the full FFI so"
    fail=1
  else
    say "PASS bridge does not need libmatrix_sdk_ffi.so"
  fi
fi
if [ "$fail" -ne 0 ]; then
  say "CLOUD_CHECK_FAIL"
  exit 1
fi
say "CLOUD_CHECK_PASS not a device result"
