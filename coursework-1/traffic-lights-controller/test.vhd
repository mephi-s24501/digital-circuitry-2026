
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package Test_Pkg is
		constant C_CLK_FREQ_HZ : integer := 40;
		constant C_CLK_PERIOD  : time    := 20 ns;
		
    constant C_TICK_FREQ_HZ : integer := 1;
    constant C_BLINK_FREQ_HZ : integer := 2;

    constant C_DUR_RED_S : integer := 10;
    constant C_DUR_RED_YEL_S : integer := 2;
    constant C_DUR_GREEN_S : integer := 8;
    constant C_DUR_GREEN_BLK_S : integer := 3;
    constant C_DUR_YELLOW_S : integer := 2;

end package Test_Pkg;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.Test_Pkg.ALL;

entity Test is
    port (
        Clk_o : out std_logic;
        Reset_o : out std_logic;

        Red_i : in std_logic;
        Yellow_i : in std_logic;
        Green_i  : in std_logic
    );
end entity Test;


architecture sim of Test is

    signal Clk_s   : std_logic := '0';
    signal Reset_s : std_logic := '0';

begin

    Clk_o <= Clk_s;
    Reset_o <= Reset_s;

    P_CLK : process
    begin
        loop
            Clk_s <= '0';
            wait for C_CLK_PERIOD / 2;

            Clk_s <= '1';
            wait for C_CLK_PERIOD / 2;
        end loop;
    end process P_CLK;


    P_RESET : process
    begin
        Reset_s <= '0';

        wait for 4 * C_CLK_PERIOD;

        Reset_s <= '1';

        wait;
    end process P_RESET;


end architecture sim;
