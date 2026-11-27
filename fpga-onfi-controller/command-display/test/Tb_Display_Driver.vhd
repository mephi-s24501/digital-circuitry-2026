library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  use std.env.all;
  use std.textio.all;
  use work.Command_Display_Pkg.all;
  use work.Tb_Utils_Pkg.all;

-- Drives the real Framebuffer and Display_Driver, then captures the I2C
-- traffic from the SDA/SCL lines.  Each 0x40 frame is written as one hex byte
-- per line (same text format as the framebuffer dump):
--
--   i2c.hex          live view after reset
--   i2c_pgup.hex     after one PgUp
--   i2c_pgdown1.hex  after the first PgDown (back at the live view)
--   i2c_pgdown2.hex  after the second PgDown

entity Tb_Display_Driver is
end entity Tb_Display_Driver;

architecture sim of Tb_Display_Driver is

  constant CLK_PERIOD_C   : time     := 20 ns;
  constant I2C_CLOCK_HZ_C : positive := 1_000_000;
  constant RESET_MS_C     : positive := 1;

  signal clk_s          : std_logic := '0';
  signal fb_rst_ns      : std_logic := '0';
  signal display_rst_ns : std_logic := '0';

  signal load_s : std_logic                     := '0';
  signal cmd_s  : onfi_command_t                := ONFI_EMPTY;
  signal row_s  : std_logic_vector(15 downto 0) := (others => '0');
  signal col_s  : std_logic_vector(15 downto 0) := (others => '0');

  signal framebuf_ptr_s  : std_logic_vector(clog2(DISPLAY_FRAMEBUFFER_LEN_C) - 1 downto 0);
  signal framebuf_busy_s : std_logic;
  signal framebuf_addr_s : std_logic_vector(7 downto 0);
  signal framebuf_data_s : std_logic_vector(FONT_DATA_WIDTH_C - 1 downto 0);

  signal scl_s : std_logic;
  signal sda_s : std_logic;

  signal pgup_n_s   : std_logic;
  signal pgdown_n_s : std_logic;

  signal shot_s : natural range 0 to 3 := 0;

begin

  scl_s <= 'H';
  sda_s <= 'H';

  u_framebuffer : entity work.Framebuffer
    port map (
      clk_i  => clk_s,
      rst_ni => fb_rst_ns,

      load_i => load_s,
      cmd_i  => cmd_s,
      row_i  => row_s,
      col_i  => col_s,

      framebuf_addr_i => framebuf_addr_s,
      framebuf_data_o => framebuf_data_s,

      framebuf_ptr_o => framebuf_ptr_s,
      busy_o         => framebuf_busy_s
    );

  dut : entity work.Display_Driver
    generic map (
      INPUT_CLOCK_HZ_G => 50_000_000,
      I2C_CLOCK_HZ_G   => I2C_CLOCK_HZ_C,
      RESET_LOW_MS_G   => RESET_MS_C,
      RESET_WAIT_MS_G  => RESET_MS_C
    )
    port map (
      clk_i  => clk_s,
      rst_ni => display_rst_ns,

      framebuf_ptr_i  => framebuf_ptr_s,
      framebuf_busy_i => framebuf_busy_s,
      framebuf_addr_o => framebuf_addr_s,
      framebuf_data_i => framebuf_data_s,

      pgup_ni   => pgup_n_s,
      pgdown_ni => pgdown_n_s,
      draw_ni   => '1',

      display_rst_no => open,
      display_cs_no  => open,
      display_dc_no  => open,
      display_scl_io => scl_s,
      display_sda_io => sda_s
    );

  tester : entity work.Display_Driver_Tester
    generic map (
      CLK_PERIOD_G => CLK_PERIOD_C
    )
    port map (
      clk_o => clk_s,

      fb_rst_no => fb_rst_ns,
      busy_i    => framebuf_busy_s,
      load_o    => load_s,
      cmd_o     => cmd_s,
      row_o     => row_s,
      col_o     => col_s,

      display_rst_no => display_rst_ns,
      pgup_no        => pgup_n_s,
      pgdown_no      => pgdown_n_s,
      shot_o         => shot_s,
      sda_io         => sda_s,
      scl_io         => scl_s
    );

end architecture sim;
