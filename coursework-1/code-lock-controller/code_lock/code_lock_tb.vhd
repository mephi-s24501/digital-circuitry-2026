library ieee;
use ieee.std_logic_1164.all;


entity code_lock_tb is
end entity code_lock_tb;


architecture behavior of code_lock_tb is

    signal clk : std_logic;
    signal reset : std_logic;
    signal keys  : std_logic_vector(9 downto 0);

    signal open_out : std_logic;
    signal error_out    : std_logic;

begin

    tester_inst : entity work.tester
        port map (
            clk   => clk,
            reset => reset,
            keys  => keys
        );

    dut_inst : entity work.code_lock
        port map (
            clk      => clk,
            reset    => reset,
            keys     => keys,
            open_out => open_out,
            error_out    => error_out
        );

end architecture behavior;