library ieee;
use ieee.std_logic_1164.all;

entity tester is
    port (
        clk   : out  std_logic;
        reset : out std_logic;
        keys  : out std_logic_vector(9 downto 0)
    );
end entity tester;

architecture behavior of tester is

    constant clk_period : time := 10 ns;
	 
	 signal clk_internal : std_logic := '0';

    procedure press_key(
	     signal clk_out  : in std_logic;
        signal keys_out : out std_logic_vector(9 downto 0);
        key_index       : integer
    ) is
    begin
   
        keys_out <= (others => '0');
        wait until rising_edge(clk_out);
        keys_out(key_index) <= '1';
        wait until rising_edge(clk_out);
        keys_out(key_index) <= '0';
        wait until rising_edge(clk_out);
		  
    end procedure;

begin

    clk_internal <= not clk_internal after clk_period / 2;
    clk <= clk_internal;

    stimulus_process: process
    begin
        reset <= '0';
        keys  <= (others => '0');
        wait for 20 ns;

        -- Сброс устройства
        reset <= '1';
        wait for 31 ns;
        reset <= '0';
        wait for 22 ns;

        -- ТЕСТ 1: Ввод правильного кода 1-2-3-4
        press_key(clk_internal, keys, 1);
        wait for 10 ns;
        press_key(clk_internal, keys, 2);
        wait for 10 ns;
        press_key(clk_internal, keys, 3);
        wait for 10 ns;
        press_key(clk_internal, keys, 4);
        wait for 50 ns;

        reset <= '1';
        wait for 30 ns;
        reset <= '0';
        wait for 20 ns;

        -- ТЕСТ 2: Ввод неправильного кода 1-6-3-7
        press_key(clk_internal, keys, 1);
        wait for 10 ns;
        press_key(clk_internal, keys, 6);
        wait for 10 ns;
        press_key(clk_internal, keys, 3);
        wait for 10 ns;
        press_key(clk_internal, keys, 7);  
        wait for 50 ns;

        reset <= '1';
        wait for 30 ns;
        reset <= '0';
        wait for 20 ns;

        wait;
    end process;

end architecture behavior;