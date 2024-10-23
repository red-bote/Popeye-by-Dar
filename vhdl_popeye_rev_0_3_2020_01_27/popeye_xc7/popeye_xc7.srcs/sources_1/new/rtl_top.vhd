----------------------------------------------------------------------------------
-- Company: Red~Bote
-- Engineer: Glenn Neidermeier
-- 
-- Create Date: 10/08/2024 08:03:34 PM
-- Design Name: 
-- Module Name: rtl_top 
-- Project Name: 
-- Target Devices: Basys 3
-- Tool Versions: 
-- Description: 
--   Top-level for Popeye by Dar  ported to Basys 3 board
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--   based on -- DE10_lite Top level for Popeye by Dar (see rtl_dar/popeye_de10_lite.vhd)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

use ieee.std_logic_unsigned.all;


entity rtl_top is
    port (
        clk : in std_logic;

        sw : in std_logic_vector (15 downto 0);

        JA : in std_logic_vector(4 downto 0);

        O_PMODAMP2_AIN : out std_logic;
        O_PMODAMP2_GAIN : out std_logic;
        O_PMODAMP2_SHUTD : out std_logic;

        vgaRed : out std_logic_vector (3 downto 0);
        vgaGreen : out std_logic_vector (3 downto 0);
        vgaBlue : out std_logic_vector (3 downto 0);
        vgaHsync : out std_logic;
        vgaVsync : out std_logic;

        led : out std_logic_vector (15 downto 0));
end rtl_top;

architecture struct of rtl_top is

    signal pll_locked : std_logic;
    signal clock_40 : std_logic;
    signal clock_kbd : std_logic;
    signal reset : std_logic;

    signal clock_div : std_logic_vector(3 downto 0);

    -- signal max3421e_clk : std_logic;

    signal r : std_logic_vector(2 downto 0);
    signal g : std_logic_vector(2 downto 0);
    signal b : std_logic_vector(1 downto 0);
    signal hsync : std_logic;
    signal vsync : std_logic;
    signal csync : std_logic;
    signal blankn : std_logic;
    signal tv15Khz_mode : std_logic;

    signal audio : std_logic_vector(15 downto 0);
    signal pwm_accumulator : std_logic_vector(17 downto 0);

    -- alias reset_n         : std_logic is key(0);
    -- alias ps2_clk         : std_logic is gpio(35); --gpio(0);
    -- alias ps2_dat         : std_logic is gpio(34); --gpio(1);
    -- alias pwm_audio_out_l : std_logic is gpio(1);  --gpio(2);
    -- alias pwm_audio_out_r : std_logic is gpio(3);  --gpio(3);

    signal kbd_intr : std_logic;
    signal kbd_scancode : std_logic_vector(7 downto 0);
    signal joy_BBBBFRLDU : std_logic_vector(8 downto 0);
    signal fn_pulse : std_logic_vector(7 downto 0);
    signal fn_toggle : std_logic_vector(7 downto 0);

    signal vsync_r : std_logic;

    -- signal start : std_logic := '0';
    -- signal usb_report : usb_report_t;
    -- signal new_usb_report : std_logic := '0';

    signal dbg_cpu_addr : std_logic_vector(15 downto 0);

    alias vga_r : std_logic_vector is vgaRed;
    alias vga_g : std_logic_vector is vgaGreen;
    alias vga_b : std_logic_vector is vgaBlue;
    alias vga_hs : std_logic is vgaHsync;
    alias vga_vs : std_logic is vgaVsync;

    component clk_wiz_0
        port (-- Clock in ports
            -- Clock out ports
            clk_out1 : out std_logic;
            -- Status and control signals
            locked : out std_logic;
            clk_in1 : in std_logic
        );
    end component;

    signal coin_in : std_logic;
    signal start_1 : std_logic;

begin

    coin_in <= not JA(4) and not JA(3); -- coin => fn_pulse(0), -- F1
    start_1 <= not JA(4) and not JA(1); -- start1 => fn_pulse(1), -- F2

    joy_BBBBFRLDU(3) <= not JA(0); -- right1 => joy_BBBBFRLDU(3),
    joy_BBBBFRLDU(2) <= not JA(1); -- left1 => joy_BBBBFRLDU(2),
    joy_BBBBFRLDU(0) <= not JA(3); -- up1 => joy_BBBBFRLDU(0),
    joy_BBBBFRLDU(1) <= not JA(2); -- down1 => joy_BBBBFRLDU(1),
    joy_BBBBFRLDU(4) <= not JA(4); -- fire1 => joy_BBBBFRLDU(4),

    reset <= '0'; -- not reset_n;

    -- Clock 40.32MHz for Video and CPU board
    clocks : clk_wiz_0
    port map(
        -- Clock out ports  
        clk_out1 => clock_40,
        -- Status and control signals
        locked => open, -- pll_locked
        -- Clock in ports
        clk_in1 => clk
    );

    -- Popeye
    popeye : entity work.popeye
        port map(
            clock_40 => clock_40,
            reset => reset,

            tv15Khz_mode => tv15Khz_mode,
            video_r => r,
            video_g => g,
            video_b => b,
            video_csync => csync,
            video_blankn => blankn,
            video_hs => hsync,
            video_vs => vsync,

            audio_out => audio,

            coin => coin_in, -- fn_pulse(0), -- F1
            start1 => start_1, -- fn_pulse(1), -- F2
            start2 => fn_pulse(2), -- F3

            right1 => joy_BBBBFRLDU(3),
            left1 => joy_BBBBFRLDU(2),
            up1 => joy_BBBBFRLDU(0),
            down1 => joy_BBBBFRLDU(1),
            fire1 => joy_BBBBFRLDU(4),

            right2 => joy_BBBBFRLDU(3),
            left2 => joy_BBBBFRLDU(2),
            up2 => joy_BBBBFRLDU(0),
            down2 => joy_BBBBFRLDU(1),
            fire2 => joy_BBBBFRLDU(4),

            sw1 => not ("10" & '1' & "1111"), -- Copyright version (2b) / N.U.(1b) / coinage (4b)
            sw2 => not ("00111101"), -- Cocktail(1b) / Music (1b) / Bonus(2b) / difficulty(2b) / life(2b)

            service => fn_toggle(6), -- F7

            dbg_cpu_addr => dbg_cpu_addr
        );

    -- adapt video to 4bits/color only and blank
    vga_r <= r & '0' when blankn = '1' else "0000";
    vga_g <= g & '0' when blankn = '1' else "0000";
    vga_b <= b & "00" when blankn = '1' else "0000";

    -- synchro composite/ synchro horizontale
    -- vga_hs <= csync;
    vga_hs <= hsync;
    --vga_hs <= csync when tv15Khz_mode = '1' else hsync;
    -- commutation rapide / synchro verticale
    -- vga_vs <= '1';
    vga_vs <= vsync;
    --vga_vs <= '1'   when tv15Khz_mode = '1' else vsync;

    -- pwm sound output
    process(clock_40)  -- use same clock as Popeye core
    begin
        if rising_edge(clock_40) then
            if clock_div = "0000" then 
                pwm_accumulator  <=  ('0'&pwm_accumulator(16 downto 0)) + ('0'&audio&'0');
            end if;
        end if;
    end process;

    --pwm_audio_out_l <= pwm_accumulator(17);
    --pwm_audio_out_r <= pwm_accumulator(17); 
    -- active-low shutdown pin
    O_PMODAMP2_SHUTD <= sw(14);
    -- gain pin is driven high there is a 6 dB gain, low is a 12 dB gain 
    O_PMODAMP2_GAIN <= sw(15);

    O_PMODAMP2_AIN <= pwm_accumulator(17);

end struct;
