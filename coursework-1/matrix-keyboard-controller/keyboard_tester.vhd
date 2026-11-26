library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

use std.env.all;

entity keyboard_tester is
    generic (
        CLK_FREQ_HZ_G         : positive  := 50_000_000;
        SCAN_FREQ_HZ_G        : positive  := 1_000;
        ROW_COUNT_G           : positive  := 4;
        COLUMN_COUNT_G        : positive  := 3;
        KEY_CODE_WIDTH_G      : positive  := 4;
        MATRIX_ACTIVE_LEVEL_G : std_logic := '0'
    );

    port (
        clk_i      : in std_logic;
        columns_i  : in std_logic_vector (0 to COLUMN_COUNT_G - 1);
        key_code_i : in std_logic_vector (KEY_CODE_WIDTH_G - 1 downto 0);

        rows_o : out std_logic_vector (0 to ROW_COUNT_G - 1);
        nRst_o : out std_logic
    );
end entity keyboard_tester;

architecture behavioral of keyboard_tester is
    constant CLK_PERIOD_C : time := 1 sec / CLK_FREQ_HZ_G;
    constant SCAN_PERIOD_C : time := 1 sec / SCAN_FREQ_HZ_G;

    -- Delay of the two-stage row synchronizer
    constant ROW_SYNC_DELAY_C : time := 2 * CLK_PERIOD_C;

    constant CLK_SETTLE_TIME_C : time := CLK_PERIOD_C / 100; -- 200 ps by default
    constant RESET_HOLD_CYCLES_C : positive := 3;

    -- Test timeouts
    constant TIMEOUT_MARGIN_C : time := SCAN_PERIOD_C;
    constant COLUMN_TIMEOUT_C : time := COLUMN_COUNT_G * SCAN_PERIOD_C + TIMEOUT_MARGIN_C;
    constant KEY_CODE_TIMEOUT_C : time := ROW_SYNC_DELAY_C + SCAN_PERIOD_C + TIMEOUT_MARGIN_C;

    -- Matrix logic
    constant MATRIX_INACTIVE_LEVEL_C : std_logic := not MATRIX_ACTIVE_LEVEL_G;
    constant ROWS_INACTIVE_C : std_logic_vector(rows_o'range) := (others => MATRIX_INACTIVE_LEVEL_C);
    constant COLUMNS_INACTIVE_C : std_logic_vector(columns_i'range) := (others => MATRIX_INACTIVE_LEVEL_C);

    constant NO_KEY_CODE_C : std_logic_vector(key_code_i'range) := (others => '0');

    -- Build a vector with exactly one active line
    function select_line (
        constant index             : in natural;
        constant inactive_template : in std_logic_vector
    )
        return std_logic_vector is
        variable value : std_logic_vector(inactive_template'range) := inactive_template;
    begin
        value(index) := MATRIX_ACTIVE_LEVEL_G;
        return value;
    end function;

    procedure check_key_code (
        constant expected  : in std_logic_vector;
        constant test_name : in string
    ) is
    begin
        assert key_code_i = expected
        report
            test_name
            & ": expected " & to_string(expected)
            & ", got " & to_string(key_code_i)
            severity error;
    end procedure;

    procedure wait_clock (
        constant cycles : in positive
    ) is
    begin
        for i in 1 to cycles loop
            wait until rising_edge(clk_i);
            wait for CLK_SETTLE_TIME_C;
        end loop;
    end procedure;

    procedure wait_for (
        signal actual      : in std_logic_vector;
        constant expected  : in std_logic_vector;
        constant timeout   : in time;
        constant test_name : in string
    ) is
    begin
        if actual /= expected then
            wait until actual = expected for timeout;
        end if;

        assert actual = expected
        report
            test_name
            & ": timeout"
            & ", expected " & to_string(expected)
            & ", got " & to_string(actual)
            severity error;
    end procedure;

begin
    run_tests : process
        procedure test_key (
            constant row    : in natural;
            constant column : in natural
        ) is
            constant KEY_NUM_C : positive := COLUMN_COUNT_G * row + column + 1;
            constant KEY_NAME_C : string := "K" & integer'image(KEY_NUM_C);

            constant EXPECTED_COLUMN_C : std_logic_vector(columns_i'range) := select_line(column, COLUMNS_INACTIVE_C);
            constant EXPECTED_KEY_CODE_C : std_logic_vector(key_code_i'range) := conv_std_logic_vector(KEY_NUM_C, KEY_CODE_WIDTH_G);
        begin
            wait_for(columns_i, EXPECTED_COLUMN_C, COLUMN_TIMEOUT_C, KEY_NAME_C & " COLUMN");

            -- Press key
            rows_o <= select_line(row, ROWS_INACTIVE_C);
            wait_for(key_code_i, EXPECTED_KEY_CODE_C, KEY_CODE_TIMEOUT_C, KEY_NAME_C & " KEY CODE");

            -- Release key
            rows_o <= ROWS_INACTIVE_C;
            wait_for(key_code_i, NO_KEY_CODE_C, KEY_CODE_TIMEOUT_C, KEY_NAME_C & " RELEASE");
        end procedure;

    begin
        -- Reset
        nRst_o <= '0';
        rows_o <= ROWS_INACTIVE_C;
        wait_clock(RESET_HOLD_CYCLES_C);
        check_key_code(NO_KEY_CODE_C, "RESET");
        nRst_o <= '1';

        for row in rows_o'range loop
            for column in columns_i'range loop
                test_key(row, column);
            end loop;
        end loop;

        report "TEST FINISHED"
            severity note;

        stop;
    end process run_tests;
end architecture behavioral;
