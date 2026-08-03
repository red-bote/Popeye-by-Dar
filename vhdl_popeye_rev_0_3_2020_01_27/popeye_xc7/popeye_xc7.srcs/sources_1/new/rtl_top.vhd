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
--   Top-level for Popeye by Dar, ported to Basys 3 board
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--   based on -- DE10_lite Top level for Popeye by Dar (see rtl_dar/popeye_de10_lite.vhd)
----------------------------------------------------------------------------------
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
--
-- Main features :
--  PS2 keyboard input : PMOD PS2 header
--  Audio pwm output   : PMOD AMD2 header 
--
--  Video         : VGA 31kHz/60Hz progressive and TV 15kHz interlaced
--  Cocktail mode : NO
--  Sound         : OK
-- 
--
-- Uses Xilinx clock IP to generate a single 40.32 MHz clock from the 100 MHz Basys3 oscillator 
--
-- Board key :
--   btnC : reset game
--
-- Keyboard players inputs :
--
--   F1 : Add coin
--   F2 : Start 1 player
--   F3 : Start 2 players
--   F7 : Service mode (press F7 once, then push btnC to reset into svc mode)
--   F8 : 31 kHz progressive

--   SPACE  : punch

--   RIGHT arrow : move right
--   LEFT  arrow : move left
--   UP    arrow : up stairs
--   DOWN  arrow : down stairs
--
-- Other details : see popeye.vhd
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library work;

entity rtl_top is
  port (
    clk           : in std_logic;
    btnC          : in std_logic;
    sw            : in std_logic_vector (15 downto 0);
    JA            : in std_logic_vector(4 downto 0);
    JB            : inout std_logic_vector(7 downto 0);

    O_PMODAMP2_AIN   : out std_logic;
    O_PMODAMP2_GAIN  : out std_logic;
    O_PMODAMP2_SHUTD : out std_logic;

    vgaRed        : out std_logic_vector (3 downto 0);
    vgaGreen      : out std_logic_vector (3 downto 0);
    vgaBlue       : out std_logic_vector (3 downto 0);
    vgaHsync      : out std_logic;
    vgaVsync      : out std_logic;

    led           : out std_logic_vector (15 downto 0)
  );
end rtl_top;

architecture struct of rtl_top is

  signal pll_locked : std_logic;
  signal clock_40 : std_logic;
  signal clock_kbd : std_logic;
  signal reset : std_logic;

  signal clock_div : std_logic_vector(3 downto 0);

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

  alias ps2_dat : std_logic is JB(0);
  alias ps2_clk : std_logic is JB(2);

  signal kbd_intr : std_logic;
  signal kbd_scancode : std_logic_vector(7 downto 0);
  signal joy_BBBBFRLDU : std_logic_vector(8 downto 0);
  signal fn_pulse : std_logic_vector(7 downto 0);
  signal fn_toggle : std_logic_vector(7 downto 0);

  signal vsync_r : std_logic;

  signal dbg_cpu_addr : std_logic_vector(15 downto 0);

  signal ja_right : std_logic;
  signal ja_left : std_logic;
  signal ja_up : std_logic;
  signal ja_down : std_logic;
  signal ja_fire : std_logic;

  signal joy_kbd : std_logic_vector(8 downto 0);

  signal popeye_coin : std_logic;
  signal popeye_start1 : std_logic;
  signal popeye_right1 : std_logic;
  signal popeye_left1 : std_logic;
  signal popeye_up1 : std_logic;
  signal popeye_down1 : std_logic;
  signal popeye_fire1 : std_logic;
  signal popeye_right2 : std_logic;
  signal popeye_left2 : std_logic;
  signal popeye_up2 : std_logic;
  signal popeye_down2 : std_logic;
  signal popeye_fire2 : std_logic;

  alias vga_r : std_logic_vector is vgaRed;
  alias vga_g : std_logic_vector is vgaGreen;
  alias vga_b : std_logic_vector is vgaBlue;
  alias vga_hs : std_logic is vgaHsync;
  alias vga_vs : std_logic is vgaVsync;

begin

  reset <= btnC; -- Basys3 buttons are active-high

  tv15Khz_mode <= sw(13);

  -- JA joystick
  ja_right <= not JA(0);
  ja_left <= not JA(1);
  ja_down <= not JA(2);
  ja_up <= not JA(3);
  ja_fire <= not JA(4);

  -- merge keyboard and joystick
  popeye_coin <= fn_pulse(0) or (ja_fire and ja_up);
  popeye_start1 <= fn_pulse(1) or (ja_fire and ja_left);
  popeye_right1 <= joy_kbd(3) or ja_right;
  popeye_left1 <= joy_kbd(2) or ja_left;
  popeye_up1 <= joy_kbd(0) or ja_up;
  popeye_down1 <= joy_kbd(1) or ja_down;
  popeye_fire1 <= joy_kbd(4) or ja_fire;
  popeye_right2 <= joy_kbd(3) or ja_right;
  popeye_left2 <= joy_kbd(2) or ja_left;
  popeye_up2 <= joy_kbd(0) or ja_up;
  popeye_down2 <= joy_kbd(1) or ja_down;
  popeye_fire2 <= joy_kbd(4) or ja_fire;

  -- Clock 40.32MHz for Video and CPU board
  clocks : entity work.clk_wiz_0
    port map (
      clk_out1 => clock_40,
      reset => reset,
      locked => pll_locked,
      clk_in1 => clk
    );

  -- Popeye
  popeye : entity work.popeye
    port map (
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

      coin => popeye_coin,
      start1 => popeye_start1,
      start2 => fn_pulse(2),

      right1 => popeye_right1,
      left1 => popeye_left1,
      up1 => popeye_up1,
      down1 => popeye_down1,
      fire1 => popeye_fire1,

      right2 => popeye_right2,
      left2 => popeye_left2,
      up2 => popeye_up2,
      down2 => popeye_down2,
      fire2 => popeye_fire2,

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
  vga_hs <= hsync;
    -- commutation rapide / synchro verticale
  vga_vs <= vsync;

  -- get scancode from keyboard
  process (reset, clock_40)
  begin
    if reset = '1' then
      clock_div <= (others => '0');
      clock_kbd <= '0';
    else
      if rising_edge(clock_40) then
        if clock_div = "1001" then
          clock_div <= (others => '0');
          clock_kbd <= not clock_kbd;
        else
          clock_div <= clock_div + '1';
        end if;
      end if;
    end if;
  end process;

  keyboard : entity work.io_ps2_keyboard
    port map (
      clk => clock_kbd, -- synchrounous clock with core
      kbd_clk => ps2_clk,
      kbd_dat => ps2_dat,
      interrupt => kbd_intr,
      scancode => kbd_scancode
    );

-- translate scancode to joystick
  joystick : entity work.kbd_joystick
    port map (
      clk => clock_kbd, -- synchrounous clock with core
      kbdint => kbd_intr,
      kbdscancode => std_logic_vector(kbd_scancode),
      joy_BBBBFRLDU => joy_kbd,
      fn_pulse => fn_pulse,
      fn_toggle => fn_toggle
    );

  -- pwm sound output (audio / 16)
  process (clock_40)
  begin
    if rising_edge(clock_40) then
      if clock_div = "0000" then
        pwm_accumulator <= ('0' & pwm_accumulator(16 downto 0)) + ("00000" & audio(15 downto 3));
      end if;
    end if;
  end process;

    -- active-low shutdown pin
  O_PMODAMP2_SHUTD <= sw(14);
  O_PMODAMP2_GAIN <= sw(15);
    -- gain pin is driven high there is a 6 dB gain, low is a 12 dB gain 
  O_PMODAMP2_AIN <= pwm_accumulator(17);

  led <= (others => '0');

end struct;
