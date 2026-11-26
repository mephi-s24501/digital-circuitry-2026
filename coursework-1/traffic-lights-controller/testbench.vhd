
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.Test_Pkg.ALL;

entity Testbench is
end entity Testbench;


architecture sim of Testbench is

    signal Clk_s : std_logic;
    signal Reset_s : std_logic;

    signal Red_s : std_logic;
    signal Yellow_s : std_logic;
    signal Green_s : std_logic;

begin

    U_TEST : entity work.Test
        port map (
            Clk_o => Clk_s,
            Reset_o => Reset_s,

            Red_i => Red_s,
            Yellow_i => Yellow_s,
            Green_i => Green_s
        );


    U_DUT : entity work.Svetofor
        generic map (
            G_CLK_FREQ_HZ => C_CLK_FREQ_HZ,
            G_TICK_FREQ_HZ => C_TICK_FREQ_HZ,
            G_BLINK_FREQ_HZ => C_BLINK_FREQ_HZ,

            G_DUR_RED_S => C_DUR_RED_S,
            G_DUR_RED_YEL_S => C_DUR_RED_YEL_S,
            G_DUR_GREEN_S => C_DUR_GREEN_S,
            G_DUR_GREEN_BLK_S => C_DUR_GREEN_BLK_S,
            G_DUR_YELLOW_S => C_DUR_YELLOW_S
        )
        port map (
            Clk_i => Clk_s,
            Reset_i => Reset_s,

            Red_o => Red_s,
            Yellow_o => Yellow_s,
            Green_o  => Green_s
        );

end architecture sim;
