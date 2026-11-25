library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  use std.env.all;
  use std.textio.all;
  use work.Onfi_Command_Pkg.all;
  use work.Tb_Utils_Pkg.all;

-- Drives Framebuffer with a handful of command pages, checks the rolling
-- pointer and the busy handshake, and dumps the used words of
-- Framebuffer_Memory to fb.hex for snapshotting.
entity Framebuffer_Tester is
  generic (
    CLK_PERIOD_C : time := 20 ns
  );
  port (
    clk_o     : out std_logic;
    rst_no    : out std_logic;

    busy_i    : in  std_logic;
    ptr_i     : in  std_logic_vector(clog2(DISPLAY_FRAMEBUFFER_LEN_C) - 1 downto 0);

    load_o    : out std_logic;
    cmd_o     : out onfi_command_t;
    row_o     : out std_logic_vector(15 downto 0);
    col_o     : out std_logic_vector(15 downto 0);

    rd_addr_o : out std_logic_vector(7 downto 0);
    rd_data_i : in  std_logic_vector(FONT_DATA_WIDTH_C - 1 downto 0)
  );
end entity Framebuffer_Tester;

architecture sim of Framebuffer_Tester is

  signal clk_s : std_logic := '0';

  --- Confirms that the framebuffer pointer is set as expected.
  procedure check_ptr (
    signal ptr        : in std_logic_vector;
    constant expected : in natural;
    constant what     : in string
  ) is
  begin
    assert (conv_integer(ptr) = expected)
      report what & ": expected ptr " & integer'image(expected) &
             ", got " & integer'image(conv_integer(ptr))
      severity failure;
  end procedure check_ptr;

  -- Walk the 200 used words through the RAM read port and write one glyph
  -- per line as hex, so runs can be diffed.
  procedure dump_framebuffer (
    signal clk    : in  std_logic;
    signal addr   : out std_logic_vector(7 downto 0);
    signal data   : in  std_logic_vector(FONT_DATA_WIDTH_C - 1 downto 0);
    constant path : in  string
  ) is
    file     f   : text;
    variable l_v : line;
  begin
    file_open(f, path, WRITE_MODE);

    for a in 0 to DISPLAY_FRAMEBUFFER_LEN_C * DISPLAY_PAGE_LEN_C - 1 loop
      addr <= conv_std_logic_vector(a, 8);
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait for 1 ns; -- required: let the registered RAM output settle for correct export
      write(l_v, to_hstring(data(GLYPH_BITS_C - 1 downto 0)));
      writeline(f, l_v);
    end loop;

    file_close(f);
  end procedure dump_framebuffer;

begin

  clk_s <= not clk_s after CLK_PERIOD_C / 2;
  clk_o <= clk_s;

  stimulus : process is
  begin
    rd_addr_o <= (others => '0');
    rst_no <= '0';
    wait_cycles(clk_s, 5);
    rst_no <= '1';
    wait_cycles(clk_s, 2);

    check_ptr(ptr_i, DISPLAY_FRAMEBUFFER_LEN_C - 1, "after reset");
    assert (busy_i = '0')
      report "busy high after reset"
      severity failure;

    send_page(clk_s, load_o, cmd_o, row_o, col_o, busy_i,
              ONFI_READ, x"0000", x"0000");
    check_ptr(ptr_i, 0, "first page");

    send_page(clk_s, load_o, cmd_o, row_o, col_o, busy_i,
              ONFI_PAGE_PROGM, x"0012", x"0034");
    check_ptr(ptr_i, 1, "second page");

    send_page(clk_s, load_o, cmd_o, row_o, col_o, busy_i,
              ONFI_RESET, x"0000", x"0000");
    check_ptr(ptr_i, 2, "third page");

    -- Fill the ring so that the next page has to wrap to slot 0.
    for i in 3 to DISPLAY_FRAMEBUFFER_LEN_C - 1 loop
      send_page(clk_s, load_o, cmd_o, row_o, col_o, busy_i,
                ONFI_READ_ID,
                conv_std_logic_vector(i, 16),
                conv_std_logic_vector(i * 2, 16));
      check_ptr(ptr_i, i, "filling ring");
    end loop;

    send_page(clk_s, load_o, cmd_o, row_o, col_o, busy_i,
              ONFI_RESET_SYNC, x"0000", x"0000");
    check_ptr(ptr_i, 0, "wrap to slot 0");

    dump_framebuffer(clk_s, rd_addr_o, rd_data_i, "fb.hex");

    report "Tb_Framebuffer: PASS"
      severity note;
    finish;
  end process stimulus;

end architecture sim;
