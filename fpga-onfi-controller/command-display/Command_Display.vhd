library ieee;
  use ieee.std_logic_1164.all;
  use work.Onfi_Command_Pkg.all;

entity Command_Display is
  generic (
    ONFI_DQ_SIZE_G   : positive := 8;
    INPUT_CLOCK_HZ_G : positive := 50_000_000;
    I2C_CLOCK_HZ_G   : positive := 300_000
  );
  port (
    onfi_dq_io : inout std_logic_vector(ONFI_DQ_SIZE_G - 1 downto 0);
    onfi_dqs_i : in    std_logic;
    onfi_re_ni : in    std_logic;
    onfi_we_ni : in    std_logic;
    onfi_cle_i : in    std_logic;
    onfi_ale_i : in    std_logic;
    onfi_rb_no : out   std_logic;

    ctrl_pgup_ni   : in std_logic;
    ctrl_pgdown_ni : in std_logic;
    ctrl_draw_ni   : in std_logic;

    load_i : in std_logic;
    row_i  : in std_logic_vector(15 downto 0);
    col_i  : in std_logic_vector(15 downto 0);
    cmd_i  : in onfi_command_t;

    display_rst_no  : out   std_logic; -- Reset #
    display_cs_no   : out   std_logic; -- Chip Select #
    display_dc_no   : out   std_logic; -- Data/Command control pin
    display_sda_io  : inout std_logic; -- I2C data OUT
    display_sdai_io : inout std_logic; -- I2C data IN (hardwired to OUT)
    display_scl_io  : inout std_logic; -- I2C clock

    clk_i  : in std_logic;
    rst_ni : in std_logic
  );
end entity Command_Display;

architecture behavioral of Command_Display is
  signal framebuf_ptr_s  : std_logic_vector(clog2(DISPLAY_FRAMEBUFFER_LEN_C) - 1 downto 0);
  signal framebuf_busy_s : std_logic;
  signal framebuf_addr_s    : std_logic_vector(7 downto 0);
  signal framebuf_data_s    : std_logic_vector(FONT_DATA_WIDTH_C - 1 downto 0);
begin
  assert ONFI_DQ_SIZE_G = 8 or ONFI_DQ_SIZE_G = 16
    report "ONFI_DQ_SIZE_G can only be 8 or 16 as per ONFI spec"
    severity error;

  display_sdai_io <= display_sda_io;

  u_framebuffer : entity work.Framebuffer
    port map (
      clk_i  => clk_i,
      rst_ni => rst_ni,

      load_i => load_i,
      row_i  => row_i,
      col_i  => col_i,
      cmd_i  => cmd_i,

      busy_o         => framebuf_busy_s,
      framebuf_ptr_o => framebuf_ptr_s,

      framebuf_addr_i => framebuf_addr_s,
      framebuf_data_o => framebuf_data_s
    );

  u_display : entity work.Display_Driver
    generic map (
      INPUT_CLOCK_HZ_G => INPUT_CLOCK_HZ_G,
      I2C_CLOCK_HZ_G   => I2C_CLOCK_HZ_G
    )
    port map (
      clk_i  => clk_i,
      rst_ni => rst_ni,

      framebuf_ptr_i  => framebuf_ptr_s,
      framebuf_busy_i => framebuf_busy_s,

      framebuf_addr_o => framebuf_addr_s,
      framebuf_data_i => framebuf_data_s,

      pgup_ni   => ctrl_pgup_ni,
      pgdown_ni => ctrl_pgdown_ni,
      draw_ni   => ctrl_draw_ni,

      display_rst_no => display_rst_no,
      display_cs_no  => display_cs_no,
      display_dc_no  => display_dc_no,
      display_scl_io => display_sda_io,
      display_sda_io => display_scl_io
    );

end architecture behavioral;
