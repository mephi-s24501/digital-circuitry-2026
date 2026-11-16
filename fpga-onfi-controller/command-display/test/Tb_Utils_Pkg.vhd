library ieee;
  use ieee.std_logic_1164.all;
  use work.Onfi_Command_Pkg.all;

-- Small helpers shared by the testbenches.
package Tb_Utils_Pkg is

  procedure wait_cycles(
    signal clk : in std_logic;
    constant n : in natural);

  procedure send_page(
    signal clk       : in  std_logic;
    signal load      : out std_logic;
    signal cmd       : out onfi_command_t;
    signal row       : out std_logic_vector(15 downto 0);
    signal col       : out std_logic_vector(15 downto 0);
    signal busy      : in  std_logic;
    constant command : in  onfi_command_t;
    constant row_val : in  std_logic_vector(15 downto 0);
    constant col_val : in  std_logic_vector(15 downto 0));

end package Tb_Utils_Pkg;

package body Tb_Utils_Pkg is

  procedure wait_cycles(
    signal clk : in std_logic;
    constant n : in natural) is
  begin
    for i in 1 to n loop
      wait until rising_edge(clk);
    end loop;
  end procedure wait_cycles;

  procedure send_page(
    signal clk       : in  std_logic;
    signal load      : out std_logic;
    signal cmd       : out onfi_command_t;
    signal row       : out std_logic_vector(15 downto 0);
    signal col       : out std_logic_vector(15 downto 0);
    signal busy      : in  std_logic;
    constant command : in  onfi_command_t;
    constant row_val : in  std_logic_vector(15 downto 0);
    constant col_val : in  std_logic_vector(15 downto 0)) is
  begin
    wait until rising_edge(clk);
    cmd  <= command;
    row  <= row_val;
    col  <= col_val;
    load <= '1';

    -- load is sampled on the next edge; drop it afterwards.
    wait until rising_edge(clk);
    load <= '0';

    wait until rising_edge(clk);
    assert (busy = '1')
      report "busy did not assert after load"
      severity failure;

    while busy = '1' loop
      wait until rising_edge(clk);
    end loop;
  end procedure send_page;

end package body Tb_Utils_Pkg;
