---------------------------------------------------------------------------------
-- Basys 3 top level for Popeye by Red~Bote, derived from popeye_de10_lite.vhd by
-- Dar (darfpga@aol.fr, http://darfpga.blogspot.fr); see that file for its
-- history.
---------------------------------------------------------------------------------
--
-- release rev 01 : initial Basys 3 release
--  (23/10/2026)
--
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
--
-- Main features :
--  PS2 keyboard input @onboard USB HID (PS/2 emulation)
--  Joystick input     @JXADC pins 1/2/3/4/7 = right/left/down/up/punch (active low)
--  Audio pwm output   @PmodAMP2 on JA pins 1/2/4; sw15 = audio disable, sw14 = gain
--
--  Video         : VGA 31kHz/60Hz progressive and TV 15kHz interlaced
--  Cocktail mode : NO
--  Sound         : OK
--
-- Uses 1 MMCM (clk_wiz_0) for 40.32MHz from 100MHz
--
-- Board buttons :
--   btnC : reset game
--   btnU, btnD : Add coin
--   btnL : Start 1 player
--   btnR : Start 2 players
--
-- Board switches :
--   sw7-0 : dip switch 2 (switch up = bit set; see port map)
--   sw11-8: dip switch 1 coinage (bits 3-0), down = default, up inverts the bit
--   sw13 : 0 = 31kHz VGA, 1 = 15kHz TV (csync on hs)
--
-- Keyboard players inputs (MAME defaults) :
--
--   5, 6 : Add coin
--   1 : Start 1 player
--   2 : Start 2 players
--   9 : Service
--   LEFT CTRL   : punch
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
use ieee.numeric_std.all;

library work;

entity popeye_basys3 is
port(
  clk            : in std_logic;
  btnC           : in std_logic;
  btnU           : in std_logic;
  btnD           : in std_logic;
  btnL           : in std_logic;
  btnR           : in std_logic;
  sw             : in std_logic_vector(15 downto 0);

  vga_r     : out std_logic_vector(3 downto 0);
  vga_g     : out std_logic_vector(3 downto 0);
  vga_b     : out std_logic_vector(3 downto 0);
  vga_hs    : out std_logic;
  vga_vs    : out std_logic;

  JXADC            : in  std_logic_vector(4 downto 0);
  ps2_clk          : in  std_logic;
  ps2_dat          : in  std_logic;
  O_PMODAMP2_AIN   : out std_logic;
  O_PMODAMP2_GAIN  : out std_logic;
  O_PMODAMP2_SHUTD : out std_logic
);
end popeye_basys3;

architecture struct of popeye_basys3 is

  signal mmcm_locked : std_logic;
  signal clock_40  : std_logic;
  signal reset     : std_logic;

  signal clock_div : std_logic_vector(3 downto 0);

  signal r         : std_logic_vector(2 downto 0);
  signal g         : std_logic_vector(2 downto 0);
  signal b         : std_logic_vector(1 downto 0);
  signal hsync     : std_logic;
  signal vsync     : std_logic;
  signal csync     : std_logic;
  signal blankn    : std_logic;
  signal tv15Khz_mode : std_logic;

  signal audio           : std_logic_vector(15 downto 0);
  signal pwm_accumulator : std_logic_vector(17 downto 0);

  -- 2-FF synchronizers for the asynchronous inputs
  signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
  signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
  signal jxadc_meta, jxadc_s     : std_logic_vector(4 downto 0) := (others => '1');
  signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0'); -- U, D, L, R
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
  attribute ASYNC_REG of jxadc_meta, jxadc_s, btn_meta, btn_s : signal is "TRUE";

  signal kbd_intr       : std_logic;
  signal kbd_scancode   : std_logic_vector(7 downto 0);
  signal kbd_rel        : std_logic := '0';
  -- kbd_key : 0 up, 1 down, 2 left, 3 right, 4 left ctrl, 5 left alt,
  --           6 '1', 7 '2', 8 '5', 9 '6', 10 '9'
  signal kbd_key        : std_logic_vector(10 downto 0) := (others => '0');
  signal joy_BBBBFRLDU  : std_logic_vector(8 downto 0);
  signal coin_in        : std_logic;
  signal start1_in      : std_logic;
  signal start2_in      : std_logic;
  signal sw2_in         : std_logic_vector(7 downto 0); -- dip switch 2 (active low)
  -- dip switch 1 : coinage (bits 3-0) on sw11-8, switch down = default, up
  -- inverts the bit; copyright version / n.u. fixed
  constant SW1_DEFAULT  : std_logic_vector(6 downto 0) := not ("10" & '1' & "1111");
  signal sw1_in         : std_logic_vector(6 downto 0);

  signal vsync_r        : std_logic;

begin

  -- btnC resets the MMCM; the core is held in reset until the MMCM locks
  reset <= btnC or not mmcm_locked;

  tv15Khz_mode <= sw(13);

  -- Clock 40.32MHz for Video and CPU board
  clocks : entity work.clk_wiz_0
  port map(
    clk_in1  => clk,
    clk_out1 => clock_40,
    reset    => btnC,
    locked   => mmcm_locked
  );

  -- synchronize asynchronous inputs to the core clock
  process(clock_40)
  begin
    if rising_edge(clock_40) then
      ps2_clk_meta <= ps2_clk;      ps2_clk_s <= ps2_clk_meta;
      ps2_dat_meta <= ps2_dat;      ps2_dat_s <= ps2_dat_meta;
      jxadc_meta   <= JXADC;        jxadc_s   <= jxadc_meta;
      btn_meta     <= btnU & btnD & btnL & btnR;
      btn_s        <= btn_meta;
    end if;
  end process;

  -- Popeye
  popeye : entity work.popeye
  port map(
    clock_40   => clock_40,
    reset      => reset,

    tv15Khz_mode => tv15Khz_mode,
    video_r      => r,
    video_g      => g,
    video_b      => b,
    video_csync  => csync,
    video_blankn => blankn,
    video_hs     => hsync,
    video_vs     => vsync,

    audio_out    => audio,

    coin          => coin_in,
    start1        => start1_in,
    start2        => start2_in,

    right1         => joy_BBBBFRLDU(3),
    left1          => joy_BBBBFRLDU(2),
    up1            => joy_BBBBFRLDU(0),
    down1          => joy_BBBBFRLDU(1),
    fire1          => joy_BBBBFRLDU(4),

    right2         => joy_BBBBFRLDU(3),
    left2          => joy_BBBBFRLDU(2),
    up2            => joy_BBBBFRLDU(0),
    down2          => joy_BBBBFRLDU(1),
    fire2          => joy_BBBBFRLDU(4),

    sw1            => sw1_in,  -- sw11-8 coinage; Copyright version (2b) / N.U.(1b) / coinage (4b)
    sw2            => sw2_in,  -- sw7-0 (default "00111101") Cocktail(1b) / Music (1b) / Bonus(2b) / difficulty(2b) / life(2b)

    service        => kbd_key(10),     -- 9 (MAME service 1)

    dbg_cpu_addr => open
  );

  -- adapt video to 4bits/color only and blank
  vga_r <= r & '0' when blankn = '1' else "0000";
  vga_g <= g & '0' when blankn = '1' else "0000";
  vga_b <= b & "00" when blankn = '1' else "0000";

  -- synchro composite/ synchro horizontale
  -- vga_hs <= csync;
  -- vga_hs <= hsync;
  vga_hs <= csync when tv15Khz_mode = '1' else hsync;
  -- commutation rapide / synchro verticale
  -- vga_vs <= '1';
  -- vga_vs <= vsync;
  vga_vs <= '1'   when tv15Khz_mode = '1' else vsync;

  -- clock divider for the pwm sound output
  process (reset, clock_40)
  begin
    if reset='1' then
      clock_div <= (others => '0');
    else
      if rising_edge(clock_40) then
        if clock_div = "1001" then
          clock_div <= (others => '0');
        else
          clock_div <= clock_div + '1';
        end if;
      end if;
    end if;
  end process;

  -- get scancode from keyboard
  keyboard : entity work.io_ps2_keyboard
  port map (
    clk       => clock_40, -- synchrounous clock with core
    kbd_clk   => ps2_clk_s,
    kbd_dat   => ps2_dat_s,
    interrupt => kbd_intr,
    scancode  => kbd_scancode
  );

  -- translate scancode to keys (MAME default keys, PS/2 set 2 codes)
  -- F0 marks a release; E0 is ignored, as in kbd_joystick (keypad 8/2/4/6
  -- also act as arrows, Right Ctrl/Alt as Left Ctrl/Alt).
  process(clock_40)
  begin
    if rising_edge(clock_40) then
      if kbd_intr = '1' then
        if kbd_scancode = x"F0" then
          kbd_rel <= '1';
        elsif kbd_scancode /= x"E0" then
          kbd_rel <= '0';
          if kbd_scancode = x"75" then kbd_key(0)  <= not kbd_rel; end if; -- up arrow
          if kbd_scancode = x"72" then kbd_key(1)  <= not kbd_rel; end if; -- down arrow
          if kbd_scancode = x"6B" then kbd_key(2)  <= not kbd_rel; end if; -- left arrow
          if kbd_scancode = x"74" then kbd_key(3)  <= not kbd_rel; end if; -- right arrow
          if kbd_scancode = x"14" then kbd_key(4)  <= not kbd_rel; end if; -- left ctrl
          if kbd_scancode = x"11" then kbd_key(5)  <= not kbd_rel; end if; -- left alt
          if kbd_scancode = x"16" then kbd_key(6)  <= not kbd_rel; end if; -- 1
          if kbd_scancode = x"1E" then kbd_key(7)  <= not kbd_rel; end if; -- 2
          if kbd_scancode = x"2E" then kbd_key(8)  <= not kbd_rel; end if; -- 5
          if kbd_scancode = x"36" then kbd_key(9)  <= not kbd_rel; end if; -- 6
          if kbd_scancode = x"46" then kbd_key(10) <= not kbd_rel; end if; -- 9
        end if;
      end if;
    end if;
  end process;

  -- merge keyboard, buttons and JXADC joystick (active low); player 2 mirrors
  -- player 1 as on the DE10-lite top
  coin_in   <= kbd_key(8) or kbd_key(9) or btn_s(3) or btn_s(2); -- 5, 6, btnU, btnD
  start1_in <= kbd_key(6) or btn_s(1); -- 1 or btnL
  start2_in <= kbd_key(7) or btn_s(0); -- 2 or btnR
  sw2_in    <= not sw(7 downto 0);     -- dip switch 2 from sw7-0
  sw1_in    <= SW1_DEFAULT xor ("000" & sw(11 downto 8)); -- coinage from sw11-8
  joy_BBBBFRLDU(0) <= kbd_key(0) or not jxadc_s(3); -- up    (JXADC4)
  joy_BBBBFRLDU(1) <= kbd_key(1) or not jxadc_s(2); -- down  (JXADC3)
  joy_BBBBFRLDU(2) <= kbd_key(2) or not jxadc_s(1); -- left  (JXADC2)
  joy_BBBBFRLDU(3) <= kbd_key(3) or not jxadc_s(0); -- right (JXADC1)
  joy_BBBBFRLDU(4) <= kbd_key(4) or not jxadc_s(4); -- punch : left ctrl (JXADC7)
  joy_BBBBFRLDU(8 downto 5) <= "0000";

  -- pwm sound output
  process(clock_40)  -- use same clock as Popeye core
  begin
    if rising_edge(clock_40) then

      if clock_div = "0000" then
        pwm_accumulator  <=  ('0'&pwm_accumulator(16 downto 0)) + ('0'&audio&'0');
      end if;

    end if;
  end process;

  O_PMODAMP2_AIN   <= pwm_accumulator(17);
  O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
  O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;
