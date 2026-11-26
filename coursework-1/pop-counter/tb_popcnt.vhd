library ieee;
use ieee.std_logic_1164.all;

entity tb_popcnt is
end entity;


architecture test of tb_popcnt is

signal clk      : std_logic;
signal nRst     : std_logic;
signal data_i     : std_logic_vector(15 downto 0);

signal quantity_o : std_logic_vector(4 downto 0);
signal done_o     : std_logic;

begin

    ------------------------------------------------------------
    -- Tester
    ------------------------------------------------------------
    tester_inst : entity work.popcnt_tester
    port map(
        clk      => clk,
        nRst     => nRst,
        data_i     => data_i,

        quantity_o => quantity_o,
        done_o     => done_o
    );


    ------------------------------------------------------------
    -- DUT
    ------------------------------------------------------------
    dut_inst : entity work.popcounter
    port map(
        data_i     => data_i,
        clk      => clk,
        nRst     => nRst,

        quantity_o => quantity_o,
        done_o     => done_o
    );

end architecture;