#!/usr/bin/env bash
# Contrato "web-recomp" do Recompendium: prepara o recompilador (idempotente).
# Não precisa de ROM nem de BIOS; a BIOS é recompilada no primeiro port.sh.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
EMSDK_VERSION=6.0.10
EMSDK="${EMSDK:-$root/tools/emsdk}"
echo "== [1/3] submódulos"
git submodule update --init external/arm-recomp-core external/recomp-net external/rbengine
echo "== [2/3] emsdk $EMSDK_VERSION"
if [ ! -f "$EMSDK/emsdk_env.sh" ] || [ ! -f "$EMSDK/.ok-$EMSDK_VERSION" ]; then
  [ -d "$EMSDK/.git" ] || git clone -q https://github.com/emscripten-core/emsdk.git "$EMSDK"
  "$EMSDK/emsdk" install "$EMSDK_VERSION" > /dev/null
  "$EMSDK/emsdk" activate "$EMSDK_VERSION" > /dev/null
  touch "$EMSDK/.ok-$EMSDK_VERSION"
fi
echo "== [3/3] gba_recompile (nativo)"
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DGBARECOMP_COMPILER_CACHE=OFF > /dev/null
cmake --build build --target gba_recompile > /dev/null
echo "== pronto"
