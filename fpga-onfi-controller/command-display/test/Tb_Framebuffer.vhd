library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  use std.env.all;
  use std.textio.all;
  use work.Onfi_Command_Pkg.all;
  use work.Tb_Utils_Pkg.all;

-- Wires Framebuffer to Framebuffer_Tester.  The tester sends the command
-- pages, checks the rolling pointer and busy handshake, and dumps the used
-- words of Framebuffer_Memory to fb.hex for snapshotting.
entity Tb_Framebuffer is
end entity Tb_Framebuffer;

architecture sim of Tb_Framebuffer is

  constant CLK_PERIOD_C : time     := 20 ns;
  constant PTR_W_C      : positive := clog2(DISPLAY_FRAMEBUFFER_LEN_C);

  signal clk_s     : std_logic                     := '0';
  signal rst_n_s   : std_logic                     := '0';
  signal load_s    : std_logic                     := '0';
  signal cmd_s     : onfi_command_t                := ONFI_READ;
  signal row_s     : std_logic_vector(15 downto 0) := (others => '0');
  signal col_s     : std_logic_vector(15 downto 0) := (others => '0');
  signal ptr_s     : std_logic_vector(PTR_W_C - 1 downto 0);
  signal busy_s    : std_logic;
  signal rd_addr_s : std_logic_vector(7 downto 0)  := (others => '0');
  signal rd_data_s : std_logic_vector(FONT_DATA_WIDTH_C - 1 downto 0);

begin

  clk_s <= not clk_s after CLK_PERIOD_C / 2;

  dut : entity work.Framebuffer
    port map (
      clk_i  => clk_s,
      rst_ni => rst_n_s,

      load_i => load_s,
      cmd_i  => cmd_s,
      row_i  => row_s,
      col_i  => col_s,

      framebuf_addr_i => rd_addr_s,
      framebuf_data_o => rd_data_s,

      framebuf_ptr_o => ptr_s,
      busy_o         => busy_s
    );

  tester : entity work.Framebuffer_Tester
    port map (
      clk_i     => clk_s,
      rst_no    => rst_n_s,

      busy_i    => busy_s,
      ptr_i     => ptr_s,

      load_o    => load_s,
      cmd_o     => cmd_s,
      row_o     => row_s,
      col_o     => col_s,

      rd_addr_o => rd_addr_s,
      rd_data_i => rd_data_s
    );

end architecture sim;
