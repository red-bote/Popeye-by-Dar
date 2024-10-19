copy /B 7a +  7b + 7c + 7e popeye_cpu.bin
make_vhdl_prom popeye_cpu.bin popeye_cpu.vhd

copy /B tpp2-c.7a + tpp2-c.7b + tpp2-c.7c + tpp2-c.7e popeye_cpu_protected.bin
make_vhdl_prom popeye_cpu_protected.bin popeye_cpu_protected.vhd

make_vhdl_prom tpp2-c.4a popeye_bg_palette_rgb.vhd
make_vhdl_prom tpp2-c.5b popeye_sp_palette_rg.vhd
make_vhdl_prom tpp2-c.5a popeye_sp_palette_gb.vhd
make_vhdl_prom tpp2-c.3a popeye_ch_palette_rgb.vhd

make_vhdl_prom tpp2-v.1e popeye_sp_bits_1.vhd
make_vhdl_prom tpp2-v.1f popeye_sp_bits_2.vhd
make_vhdl_prom tpp2-v.1j popeye_sp_bits_3.vhd
make_vhdl_prom tpp2-v.1k popeye_sp_bits_4.vhd

make_vhdl_prom tpp2-v.5n popeye_ch_bits.vhd


rem ROM from popeye.zip (rev D protected)

rem tpp2-c.7a CRC 9af7c821
rem tpp2-c.7b CRC c3704958
rem tpp2-c.7c CRC 5882ebf9
rem tpp2-c.7e CRC ef8649ca

rem ROM from popeyeu.zip
rem
rem 7a CRC 0bd04389
rem 7b CRC efdf02c3
rem 7c CRC 8eee859e
rem 7e CRC b64aa314


rem ROM from popeye.zip
rem
rem tpp2-v.5n CRC cca61ddd
rem tpp2-v.1e CRC 0f2cd853
rem tpp2-v.1f CRC 888f3474
rem tpp2-v.1j CRC 7e864668
rem tpp2-v.1k CRC 49e1d170
rem tpp2-c.4a CRC 375e1602
rem tpp2-c.3a CRC e950bea1
rem tpp2-c.5b CRC c5826883
rem tpp2-c.5a CRC c576afba
