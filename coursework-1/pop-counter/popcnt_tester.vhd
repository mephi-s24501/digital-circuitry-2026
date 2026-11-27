library ieee;
use ieee.std_logic_1164.all;

entity popcnt_tester is
port(
    clk        : out std_logic;
    nRst       : out std_logic;
    data_i     : out std_logic_vector(15 downto 0);
    quantity_o : in  std_logic_vector(4 downto 0);
    done_o     : in  std_logic
);
end entity;

architecture test of popcnt_tester is
    constant CLK_PERIOD  : time := 10 ns;
    constant SETTLE_TIME : time := 1 ns;
    signal clk_r         : std_logic := '0';
    signal finished_flag : std_logic := '0';
begin
    clk <= clk_r;

    clk_gen : process
    begin
        while finished_flag = '0' loop
            clk_r <= '0';
            wait for CLK_PERIOD / 2;
            clk_r <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        clk_r <= '0';
        wait;
    end process;

    stimulus : process
        procedure apply_test(
            constant data_value  : in std_logic_vector(15 downto 0);
            constant expected    : in std_logic_vector(4 downto 0);
            constant test_num    : in integer;
            constant expect_drop : in boolean := true
        ) is
            variable previous_quantity_v : std_logic_vector(4 downto 0);
        begin
            wait until falling_edge(clk_r);
            previous_quantity_v := quantity_o;
            data_i <= data_value;
            -- Задержка учитывает delta cycles RTL, а не физические задержки FPGA.
            wait for SETTLE_TIME;
            assert (expect_drop and done_o = '0') or
                   ((not expect_drop) and done_o = '1')
                report "Test " & integer'image(test_num) &
                    ": FAIL - unexpected done_o before rising edge"
                severity failure;
            assert quantity_o = previous_quantity_v
                report "Test " & integer'image(test_num) &
                    ": FAIL - quantity_o changed before rising edge"
                severity failure;

            wait until rising_edge(clk_r);
            wait for SETTLE_TIME;
            assert quantity_o = expected
                report "Test " & integer'image(test_num) &
                    ": FAIL - incorrect popcount result"
                severity failure;
            assert done_o = '1'
                report "Test " & integer'image(test_num) &
                    ": FAIL - done_o must be 1 after rising edge"
                severity failure;
            report "Test " & integer'image(test_num) & ": PASS" severity note;
        end procedure;
    begin
        -- Начальный reset: выходы очищаются до первого фронта.
        nRst <= '0';
        data_i <= (others => '0');
        wait for SETTLE_TIME;
        assert done_o = '0' and quantity_o = "00000"
            report "Initial reset: FAIL - outputs must be zero"
            severity failure;
        report "Initial reset: PASS" severity note;

        -- Снимаем reset после фронта, чтобы Test 1 проверил первый захват.
        wait until rising_edge(clk_r);
        wait for SETTLE_TIME;
        nRst <= '1';
        apply_test(x"0000", "00000", 1);
        apply_test(x"0001", "00001", 2);
        apply_test(x"000B", "00011", 3);
        apply_test(x"AAAA", "01000", 4);
        apply_test(x"5555", "01000", 5);
        apply_test(x"FFFF", "10000", 6);

        -- Сбрасываем ненулевой результат коротким импульсом между фронтами.
        wait until falling_edge(clk_r);
        wait for SETTLE_TIME;
        nRst <= '0';
        wait for SETTLE_TIME;
        assert done_o = '0' and quantity_o = "00000"
            report "Repeated reset: FAIL - outputs did not clear asynchronously"
            severity failure;
        nRst <= '1';
        wait for SETTLE_TIME;
        assert done_o = '0' and quantity_o = "00000"
            report "Repeated reset: FAIL - result became valid before rising edge"
            severity failure;
        wait until rising_edge(clk_r);
        wait for SETTLE_TIME;
        assert done_o = '1' and quantity_o = "10000"
            report "Repeated reset: FAIL - incorrect first result after reset"
            severity failure;
        report "Repeated reset: PASS" severity note;

        apply_test(x"0000", "00000", 7);
        apply_test(x"0000", "00000", 8, false);
        report "All tests completed successfully" severity note;
        finished_flag <= '1';
        wait;
    end process;
end architecture;