#!/bin/sh
# Inspect whether libhm_sdk_diag.so imports C++ runtime symbols.
# memcpy and memset are libc, not libc++. Prefer llvm-readelf/llvm-nm
# (DevEco) and fall back to binutils. This script never copies a library.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DIAG=${1:-$ROOT/hap-diag/entry/libs/arm64-v8a/libhm_sdk_diag.so}
LIBCXX=${2:-}

pick() {
  for c in "$@"; do
    if command -v "$c" >/dev/null 2>&1; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 1
}
READELF=$(pick llvm-readelf readelf) || { echo "need llvm-readelf or readelf" >&2; exit 2; }
NM=$(pick llvm-nm nm) || { echo "need llvm-nm or nm" >&2; exit 2; }

if [ ! -f "$DIAG" ]; then
  echo "missing $DIAG" >&2
  exit 2
fi
echo "readelf=$READELF"
echo "nm=$NM"
echo "diag=$DIAG"
"$READELF" -d "$DIAG" | awk '/NEEDED|SONAME/'
cxx=0
"$NM" -D "$DIAG" | awk '$1=="U" {print $2}' | while read -r sym; do
  [ -n "$sym" ] || continue
  case "$sym" in
    memcpy|memset|memmove|memcmp|malloc|free|calloc|realloc|strlen|strcmp|strcpy|strncmp|strncpy|abort|fprintf|snprintf)
      echo "LIBC $sym"
      ;;
    __memcpy*|*memcpy@*|*memset@*)
      echo "LIBC $sym"
      ;;
    _Z*|__cxa_*|__gxx_*|_Unwind_*)
      echo "CXX $sym"
      ;;
    hm_sdk_*|napi_*)
      ;;
    *)
      echo "OTHER $sym"
      ;;
  esac
done > /tmp/hm-libcxx-class.txt
cat /tmp/hm-libcxx-class.txt
if grep -q '^CXX ' /tmp/hm-libcxx-class.txt; then
  cxx=1
fi
if [ "$cxx" -eq 0 ]; then
  echo "No C++ symbols are imported. Do not add libc++_shared.so."
  exit 0
fi
if [ -z "$LIBCXX" ]; then
  echo "C++ symbols are imported. Pass the HarmonyOS SDK 26.0.0.105 libc++_shared.so as the second argument." >&2
  echo "Do not use the OpenHarmony 7.0-Beta1 copy unless that check passes and a device load is still pending." >&2
  exit 1
fi
status=0
grep '^CXX ' /tmp/hm-libcxx-class.txt | awk '{print $2}' | while read -r sym; do
  if ! "$NM" -D --defined-only "$LIBCXX" | awk '{print $NF}' | grep -Fxq "$sym"; then
    echo "UNRESOLVED $sym"
    status=1
  fi
done
# Re-check outside the pipeline subshell.
missing=0
while read -r sym; do
  if ! "$NM" -D --defined-only "$LIBCXX" | awk '{print $NF}' | grep -Fxq "$sym"; then
    echo "UNRESOLVED $sym"
    missing=1
  fi
done << EOF
$(grep '^CXX ' /tmp/hm-libcxx-class.txt | awk '{print $2}')
EOF
if [ "$missing" -ne 0 ]; then
  echo "This libc++_shared.so does not define every C++ symbol. Do not package it." >&2
  exit 1
fi
echo "C++ symbol names match the supplied libc++_shared.so. Device load remains unverified."
