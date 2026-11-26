#!/usr/bin/env bash
# Contrato "web-recomp" do Recompendium: scripts/port.sh <nome> <rom.gba>
# Gera build/web-<nome>/ (index.html + game.js/.wasm + ROM e BIOS embutidas).
# A saída leva a ROM e a BIOS do dono da instância: é só pra instância dele, nunca publicar.
# BIOS: $GBA_BIOS, senão <pasta da ROM>/bios/gba_bios.bin, senão bios/gba_bios.bin.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
[ $# -eq 2 ] || { echo "uso: $0 <nome> <rom.gba>" >&2; exit 2; }
name="$1"; rom="$(realpath "$2")"
export EMSDK="${EMSDK:-$root/tools/emsdk}"
work="$root/games/$name"
out="$root/build/web-$name"
[ -x "$root/build/gba_recompile" ] || { echo "erro: rode scripts/setup.sh antes" >&2; exit 1; }
bios=""
for c in "${GBA_BIOS:-}" "$(dirname "$rom")/bios/gba_bios.bin" "$root/bios/gba_bios.bin"; do
  [ -n "$c" ] && [ -f "$c" ] && { bios="$c"; break; }
done
[ -n "$bios" ] || { echo "erro: BIOS do GBA não encontrada (gba_bios.bin em <pasta da ROM>/bios/ ou GBA_BIOS=)" >&2; exit 1; }
sha1() { sha1sum "$1" | cut -d' ' -f1; }
bios_sha=$(sha1 "$bios")
[ "$bios_sha" = 300c20df6731a33952ded8c436f7f186d25d3492 ] || { echo "erro: BIOS com SHA-1 $bios_sha; o gbarecomp só aceita a BIOS oficial (300c20df…)" >&2; exit 1; }

echo "== [1/4] BIOS recompilada"
gen_bios="$root/build/generated_bios"
if [ ! -s "$gen_bios/bios_recompiled.cpp" ]; then
  "$root/build/gba_recompile" --bios "$bios" --config "$root/bios/gba_bios.toml" --out "$gen_bios" > /dev/null
fi

echo "== [2/4] recompilando o cartucho"
rm -rf "$work"; mkdir -p "$work"
# sem config por jogo: análise genérica + interpretador onde faltar cobertura estática
printf '[game]\nname = "%s"\n[rom]\nsha1 = "%s"\n' "$name" "$(sha1 "$rom")" > "$work/game.toml"
GBARECOMP_CORE="$root/build/gba_recompile" python3 "$root/tools/cli.py" build \
  --rom "$rom" --output "$work/project" --force > "$work/recompile.log" 2>&1 \
  || { tail -20 "$work/recompile.log" >&2; echo "erro: o recompilador falhou neste cartucho" >&2; exit 1; }

echo "== [3/4] compilando WASM"
GBARECOMP_WEB_OUT_DIR="$work/web" bash "$root/packaging/web/build_web.sh" --embed-private-rom \
  "$work/project" "$gen_bios" "$rom" "$bios" "$work/game.toml" > "$work/web.log" 2>&1 \
  || { tail -20 "$work/web.log" >&2; echo "erro: falha ao compilar o WASM" >&2; exit 1; }

echo "== [4/4] publicando"
rm -rf "$out"; mkdir -p "$(dirname "$out")"
mv "$work/web" "$out"
rm -f "$out"/*.symbols
# instância própria: ROM/BIOS já embutidas, então começa sozinho (?autostart=0 desliga)
sed -i "s/q.get('autostart')==='1'/q.get('autostart')!=='0'/" "$out/bootstrap.js"
grep -q "q.get('autostart')!=='0'" "$out/bootstrap.js" || { echo "erro: não achei o autostart no bootstrap.js" >&2; exit 1; }
# gravação de diagnóstico (replay de até 256 MiB na memória) desligada por padrão no hub
sed -i "s/const env={};for(const item/const env={GBARECOMP_DIAGNOSTICS:'0'};for(const item/" "$out/bootstrap.js"
grep -q "GBARECOMP_DIAGNOSTICS:'0'" "$out/bootstrap.js" || { echo "erro: não achei o env no bootstrap.js" >&2; exit 1; }
python3 "$root/scripts/hub-page.py" "$out/index.html"
rm -rf "$work/project"   # C++ gerado é grande e sai de novo a cada build
echo "== pronto: $out"
