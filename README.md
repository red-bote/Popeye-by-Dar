# Popeye-by-Dar

Popeye (Nintendo), FPGA core by Dar (<http://darfpga.blogspot.fr>), ported to Digilent
Basys 3 (`xc7a35tcpg236-1`). Upstream:
<https://sourceforge.net/projects/darfpga/files/Software%20VHDL/popeye/>
(`vhdl_popeye_rev_0_3_2020_01_27.zip`, rev 0.3).

## Hardware

- Basys 3; VGA monitor (31 kHz) or 15 kHz TV, interlaced (sw13, not verified).
- Keyboard on the onboard USB HID port.
- Optional: Atari-compatible joystick on Pmod JXADC (pins 1/2/3/4/7 =
  right/left/down/up/punch, active low, pull-ups in the XDC).
- Optional: [PmodAMP2](https://digilent.com/reference/pmod/pmodamp2/start) on Pmod JA,
  pins 1/2/4.

## Build

Requires gcc, unzip, Vivado 2020.2, and
[openFPGALoader](https://github.com/trabucayre/openFPGALoader) (`make load` only).

```
make help        # list all targets
make roms        # popeye.zip, popeyeu.zip from $ROMDIR
make bitstream   # Vivado batch build (runs make roms first if needed)
make load        # program the Basys 3 over USB (SRAM, lost at power-off)
```

Overrides, as make arguments or environment variables:
`VIVADO=<path>/bin/vivado` (default `/tools/Xilinx/Vivado/2020.2/bin/vivado`),
`ROMDIR=<dir>` (default `~/roms`), `ROMZIP=<zip>[,<zip>]`.

`popeyeu.zip` supplies the unprotected program ROMs (7a/7b/7c/7e).

ROMs are not included. Do not redistribute roms or anything generated from them.

## IO

Keys follow the MAME defaults. Player 2 shares the player 1 controls.

| Action   | Keyboard  | Basys 3                                               |
|----------|-----------|-------------------------------------------------------|
| move     | arrows    | JXADC joystick                                        |
| punch    | Left Ctrl | JXADC pin 7                                           |
| start 1P | 1         | btnL                                                  |
| start 2P | 2         | btnR                                                  |
| coin     | 5 / 6     | btnU / btnD                                           |
| service  | 9         |                                                       |
| reset    |           | btnC                                                  |
| dips     |           | sw7-0 (dip switch 2, up = 1; default: sw5/4/3/2/0 up) |
| coinage  |           | sw11-8 (dip switch 1 coinage; down = default)         |
| display  |           | sw13 (down 31 kHz, up 15 kHz)                         |
| amp gain |           | sw14 (up gain active)                                 |
| audio    |           | sw15 (up disabled)                                    |

## Issues Addressed

- CPU and AY ran about 25% fast (4-bit `clock_cnt2` never reached its reload of 19):
  widened to 5 bits (`contrib/patches/popeye_clock_cnt2_width.patch`).
- Incomplete sensitivity list in `ym_2149_linmix.vhd` (Synth 8-614): `ioa_inreg` and
  `iob_inreg` added (`contrib/patches/popeye_linmix_sensitivity.patch`).

## License

- Basys 3 port additions: MIT, see `LICENSE` (scope stated there).
- DarFPGA sources: educational use only; do not redistribute synthesized files with roms
  (see `vhdl_popeye_rev_0_3_2020_01_27/README.txt`).
- T80 CPU (`rtl_t80_304/`): BSD-style, Daniel Wallner et al.
- YM2149 sound (`rtl_mikej/`): BSD-style, MikeJ.
