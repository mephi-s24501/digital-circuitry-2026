library ieee;
use ieee.std_logic_1164.all;

entity dut_lab1 is
  generic (
    -- в тесте переопределяется, на плате остаётся дефолт
    scan_div_c : natural := 50000
  );
  port (
    data_i   : in  std_logic_vector(15 downto 0);
    update_li: in  std_logic;
    clk_i    : in  std_logic;
    nRst_li  : in  std_logic;
    seg_o    : out std_logic_vector(6 downto 0);
    digit_o  : out std_logic_vector(3 downto 0)
  );
end entity dut_lab1;

architecture rtl of dut_lab1 is
  signal bcd_s        : std_logic_vector(15 downto 0);
  signal segs_s       : std_logic_vector(27 downto 0);
  signal segs_mem_o_s : std_logic_vector(27 downto 0);
begin

  u_conv : entity work.dut_bin_to_bcd
    port map (
      data_i => data_i,
      bcd_o  => bcd_s
    );

  u_dec0 : entity work.dut_seven_seg
    port map (
      bcd_i => bcd_s(3 downto 0),
      seg_o => segs_s(6 downto 0)
    );

  u_dec1 : entity work.dut_seven_seg
    port map (
      bcd_i => bcd_s(7 downto 4),
      seg_o => segs_s(13 downto 7)
    );

  u_dec2 : entity work.dut_seven_seg
    port map (
      bcd_i => bcd_s(11 downto 8),
      seg_o => segs_s(20 downto 14)
    );

  u_dec3 : entity work.dut_seven_seg
    port map (
      bcd_i => bcd_s(15 downto 12),
      seg_o => segs_s(27 downto 21)
    );

  u_mem : entity work.dut_segment_memory
    port map (
      segments_i => segs_s,
      update_li  => update_li,
      clk_i      => clk_i,
      nRst_li    => nRst_li,
      segments_o => segs_mem_o_s
    );

  u_mux : entity work.dut_display_mux
    generic map (
      scan_div_c => scan_div_c
    )
    port map (
      segments_i => segs_mem_o_s,
      clk_i      => clk_i,
      nRst_li    => nRst_li,
      seg_o      => seg_o,
      digit_o    => digit_o
    );

end architecture rtl;
