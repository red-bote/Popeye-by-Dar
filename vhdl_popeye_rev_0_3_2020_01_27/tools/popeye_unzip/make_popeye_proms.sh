#!/bin/bash
# Port of make_popeye_proms.bat for the Basys3 build. Run from this
# directory (the unzipped popeye.zip + popeyeu.zip) by contrib/tools/roms.sh, which sets:
#   MAKE_VHDL_PROM  path of the compiled make_vhdl_prom
#   PROM_DIR        output directory for the PROM VHDL
# make_vhdl_prom names the entity after its output argument, so it runs inside
# PROM_DIR with bare output file names.
# popeyeu.zip provides the unprotected program ROMs 7a/7b/7c/7e; popeye.zip the
# protected tpp2-c.7* set and the graphics/palette PROMs.

set -euo pipefail

: "${MAKE_VHDL_PROM:?}" "${PROM_DIR:?}"
roms="$(pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat 7a 7b 7c 7e > "$tmp/popeye_cpu.bin"
cat tpp2-c.7a tpp2-c.7b tpp2-c.7c tpp2-c.7e > "$tmp/popeye_cpu_protected.bin"

cd "$PROM_DIR"
"$MAKE_VHDL_PROM" "$tmp/popeye_cpu.bin"           popeye_cpu.vhd
"$MAKE_VHDL_PROM" "$tmp/popeye_cpu_protected.bin" popeye_cpu_protected.vhd
"$MAKE_VHDL_PROM" "$roms/tpp2-c.4a"               popeye_bg_palette_rgb.vhd
"$MAKE_VHDL_PROM" "$roms/tpp2-c.5b"               popeye_sp_palette_rg.vhd
"$MAKE_VHDL_PROM" "$roms/tpp2-c.5a"               popeye_sp_palette_gb.vhd
"$MAKE_VHDL_PROM" "$roms/tpp2-c.3a"               popeye_ch_palette_rgb.vhd
"$MAKE_VHDL_PROM" "$roms/tpp2-v.1e"               popeye_sp_bits_1.vhd
"$MAKE_VHDL_PROM" "$roms/tpp2-v.1f"               popeye_sp_bits_2.vhd
"$MAKE_VHDL_PROM" "$roms/tpp2-v.1j"               popeye_sp_bits_3.vhd
"$MAKE_VHDL_PROM" "$roms/tpp2-v.1k"               popeye_sp_bits_4.vhd
"$MAKE_VHDL_PROM" "$roms/tpp2-v.5n"               popeye_ch_bits.vhd
