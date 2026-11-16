library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  use std.env.all;
  use std.textio.all;
  use work.Onfi_Command_Pkg.all;
  use work.Tb_Utils_Pkg.all;

-- Drives the real Framebuffer and Display_Driver, then captures the I2C
-- traffic from the SDA/SCL lines.  The GDDRAM payload of the 0x40 frame is
-- written to i2c.hex as one hex byte per line (same text format as the
-- framebuffer dump), so the rendered picture shows the actual command text.
--
-- The newest page is displayed on the upper two text rows and its
-- predecessor on the lower two rows:
--
--   RESET SYNC
--   0000 0000
--   PAGE PROGM
--   0012 0034
entity Tb_Display_Driver is
end entity Tb_Display_Driver;

architecture sim of Tb_Display_Driver is

  constant CLK_PERIOD_C   : time     := 20 ns;
  constant I2C_CLOCK_HZ_C : positive := 1_000_000;
  constant RESET_MS_C     : positive := 1;

  signal clk_s      : std_logic := '0';
  signal fb_rst_ns : std_logic := '0';
  signal display_rst_ns : std_logic := '0';

  signal load_s : std_logic := '0';
  signal cmd_s  : onfi_command_t := ONFI_READ;
  signal row_s  : std_logic_vector(15 downto 0) := (others => '0');
  signal col_s  : std_logic_vector(15 downto 0) := (others => '0');

  signal ptr_s     : std_logic_vector(clog2(DISPLAY_FRAMEBUFFER_LEN_C) - 1 downto 0);
  signal busy_s    : std_logic;
  signal fb_addr_s : std_logic_vector(7 downto 0);
  signal fb_data_s : std_logic_vector(FONT_DATA_WIDTH_C - 1 downto 0);

  signal scl_s : std_logic;
  signal sda_s : std_logic;

begin

  clk_s <= not clk_s after CLK_PERIOD_C / 2;

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

      framebuf_addr_i => fb_addr_s,
      framebuf_data_o => fb_data_s,

      framebuf_ptr_o => ptr_s,
      busy_o         => busy_s
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

      framebuf_ptr_i  => ptr_s,
      framebuf_busy_i => busy_s,
      framebuf_addr_o => fb_addr_s,
      framebuf_data_i => fb_data_s,

      pgup_ni   => '1',
      pgdown_ni => '1',
      draw_ni   => '1',

      display_rst_no => open,
      display_cs_no  => open,
      display_dc_no  => open,
      display_scl_io => scl_s,
      display_sda_io => sda_s
    );

  tester : entity work.Display_Driver_Tester
    port map (
      clk_i          => clk_s,

      fb_rst_no      => fb_rst_ns,
      busy_i         => busy_s,
      load_o         => load_s,
      cmd_o          => cmd_s,
      row_o          => row_s,
      col_o          => col_s,

      display_rst_no => display_rst_ns,
      sda_io         => sda_s,
      scl_io         => scl_s
   );
end architecture sim;
