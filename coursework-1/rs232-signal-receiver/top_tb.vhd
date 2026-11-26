library ieee;
  use ieee.std_logic_1164.all;

entity top_tb is
end entity top_tb;

architecture behavioral of top_tb is

  constant n        : natural := 8;
  constant end_bits : natural := 2; -- stop bits, must match top and tester

  signal clki    : std_logic; -- 50 MHz board clock
  signal rst_n   : std_logic;
  signal data_in : std_logic;
  signal clk0    : std_logic; -- 5 MHz PLL output
  signal data    : std_logic_vector(n - 1 downto 0);
  signal sel     : std_logic_vector(2 downto 0);
  signal led     : std_logic_vector(6 downto 0);
  signal err     : std_logic;
  signal done    : std_logic;

begin

  u_tester : entity work.tester(sim)
    generic map (
      n        => n,
      end_bits => end_bits
    )
    port map (
      clk_i  => clk0,
      data_i => data,
      err_i  => err,
      done_i => done,
      clki_o => clki,
      rst_no => rst_n,
      data_o => data_in
    );

  u_dut : entity work.top
    port map (
      clki_i         => clki,
      rst_ni         => rst_n,
      data_i         => data_in,
      data_out_o     => data,
      selected_cnt_o => sel,
      led_out_o      => led,
      err_o          => err,
      out_en_o       => done,
      clk0_o         => clk0
    );

end architecture behavioral;
