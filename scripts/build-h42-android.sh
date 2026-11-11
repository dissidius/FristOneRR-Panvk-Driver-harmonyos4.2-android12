#!/usr/bin/env bash
# Experimental FristOneRR PanVK Android arm64 build from a pinned patched source.
# Usage: scripts/build-h42-android.sh PATH_TO_MESA PATH_TO_NDK
set -euo pipefail
SOURCE="$(realpath "${1:?missing source tree}")"
NDK="$(realpath "${2:?missing Android NDK}")"
ROOT="$(pwd)"
NDK_BIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
test -x "$NDK_BIN/aarch64-linux-android31-clang" || {
  echo "BUILD-ERROR: missing NDK Android 31 compiler"; exit 1;
}
cd "$SOURCE"
# This fork links Android liblog unconditionally even for native host codegen
# tools. Keep the link for Android, but not for Linux host executables.
python3 - <<'PY'
from pathlib import Path
p=Path("meson.build")
s=p.read_text()
old="add_project_link_arguments(\n  '-llog',\n  language : ['c', 'cpp'],\n)"
new="if host_machine.system() == 'android'\n"+old+"\nendif"
if s.count(old)!=1:
    raise SystemExit("Cannot safely guard FristOneRR's Android-only liblog")
p.write_text(s.replace(old,new,1))
PY
HOST_BUILD=build-h42-host
ANDROID_BUILD=build-h42-android

# Mesa's offline shader compilers must be built natively before cross compiling.
meson setup "$HOST_BUILD" -Dbuildtype=release \
  -Dmesa-clc=enabled -Dprecomp-compiler=enabled -Dpanfrost-rust=false \
  -Dvulkan-drivers=panfrost -Dpanfrost-kmds=kbase -Dgallium-drivers= \
  -Dplatforms= -Dllvm=enabled -Dgles1=disabled -Dgles2=disabled \
  -Degl=disabled -Dglx=disabled -Dgbm=disabled -Dtools= \
  -Dvideo-codecs= -Dzstd=disabled \
  --force-fallback-for=libdrm,expat,zlib
ninja -C "$HOST_BUILD" -j 4 \
  src/compiler/clc/mesa_clc \
  src/compiler/spirv/vtn_bindgen2 \
  src/panfrost/clc/panfrost_compile
mkdir -p "$HOST_BUILD/bin"
cp "$HOST_BUILD/src/compiler/clc/mesa_clc" \
   "$HOST_BUILD/src/compiler/spirv/vtn_bindgen2" \
   "$HOST_BUILD/src/panfrost/clc/panfrost_compile" "$HOST_BUILD/bin/"
export PATH="$SOURCE/$HOST_BUILD/bin:$PATH"

mkdir -p "$ANDROID_BUILD/pkgconfig-empty"
cat > "$ANDROID_BUILD/h42-cross.ini" <<CROSS
[binaries]
c = '$NDK_BIN/aarch64-linux-android31-clang'
cpp = '$NDK_BIN/aarch64-linux-android31-clang++'
ar = '$NDK_BIN/llvm-ar'
strip = '$NDK_BIN/llvm-strip'
pkg-config = 'pkg-config'

[properties]
pkg_config_libdir = ['$SOURCE/$ANDROID_BUILD/pkgconfig-empty']
cpp_link_args = ['-static-libstdc++']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
CROSS

meson setup "$ANDROID_BUILD" --cross-file "$ANDROID_BUILD/h42-cross.ini" \
  -Dbuildtype=release -Db_ndebug=true \
  -Dplatforms=android -Dplatform-sdk-version=31 \
  -Dandroid-stub=true -Dandroid-strict=false \
  -Dandroid-libbacktrace=disabled -Dpanfrost-rust=false \
  -Dvulkan-drivers=panfrost -Dpanfrost-kmds=kbase \
  -Dgallium-drivers= -Dvulkan-layers= -Dtools= -Dvideo-codecs= \
  -Dmesa-clc=system -Dprecomp-compiler=system -Dllvm=disabled \
  -Dzstd=disabled -Dglx=disabled -Dgbm=disabled -Degl=disabled \
  -Dgles1=disabled -Dgles2=disabled \
  --force-fallback-for=libdrm,expat,zlib
ninja -C "$ANDROID_BUILD" -j 4 src/panfrost/vulkan/libvulkan_panfrost.so

SO="$ANDROID_BUILD/src/panfrost/vulkan/libvulkan_panfrost.so"
test -s "$SO"
mkdir -p "$ROOT/dist/generic" "$ROOT/dist/armsx2"
"$NDK_BIN/llvm-strip" -o "$ROOT/dist/generic/libvulkan_panfrost.so" "$SO"
cp "$ROOT/dist/generic/libvulkan_panfrost.so" "$ROOT/dist/armsx2/libvulkan_freedreno.so"
python3 - "$ROOT/dist" <<'PY'
import json, pathlib, sys
out=pathlib.Path(sys.argv[1])
for sub,name,lib in [
 ("generic","FristOneRR PanVK Huawei Kirin990 H42 experimental","libvulkan_panfrost.so"),
 ("armsx2","FristOneRR PanVK Huawei Kirin990 H42 ARMSX2 experimental","libvulkan_freedreno.so"),
]:
  meta={"schemaVersion":1,"name":name,"author":"dissidius / FristOneRR",
        "packageVersion":"0.0.1","driverVersion":"FristOneRR-efd07ba-H42",
        "minApi":31,"libraryName":lib,
        "description":"Unverified experimental 32-byte MEM_IMPORT compatibility build; requires Huawei device tests"}
  (out/sub/"meta.json").write_text(json.dumps(meta,indent=2)+"\n")
PY
(cd "$ROOT/dist/generic" && zip -q ../FristOneRR-PanVK-H42-EXPERIMENTAL.zip libvulkan_panfrost.so meta.json)
(cd "$ROOT/dist/armsx2" && zip -q ../FristOneRR-PanVK-H42-ARMSX2-EXPERIMENTAL.zip libvulkan_freedreno.so meta.json)
(cd "$ROOT/dist" && sha256sum *EXPERIMENTAL.zip > SHA256SUMS.txt)
echo "Build complete: $ROOT/dist/"
