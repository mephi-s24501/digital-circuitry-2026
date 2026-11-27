library ieee;
use ieee.std_logic_1164.all;

entity tb_lab1 is
end entity tb_lab1;

architecture sim of tb_lab1 is
  signal data_s    : std_logic_vector(15 downto 0) := (others => '0');
  signal update_ls : std_logic := '0';
  signal nRst_ls   : std_logic := '1';
  signal clk_ls    : std_logic := '0';
  signal seg_ls    : std_logic_vector(6 downto 0);
  signal digit_ls  : std_logic_vector(3 downto 0);
begin
  uut : entity work.dut_lab1
    generic map (
      scan_div_g => 1
    )
    port map (
      data_i    => data_s,
      update_li => update_ls,
      clk_i     => clk_ls,
      nRst_li   => nRst_ls,
      seg_o     => seg_ls,
      digit_o   => digit_ls
    );

  u_tester : entity work.low_tester
    port map (
      data_o   => data_s,
      update_o => update_ls,
      nRst_o   => nRst_ls,
      clk_o    => clk_ls,
      seg_i    => seg_ls,
      digit_i  => digit_ls
    );
end architecture sim;