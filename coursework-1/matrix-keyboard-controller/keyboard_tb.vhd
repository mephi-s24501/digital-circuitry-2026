library ieee;
use ieee.std_logic_1164.all;

entity keyboard_tb is
end entity keyboard_tb;

architecture behavioral of keyboard_tb is
    constant CLK_FREQ_HZ_C : positive := 50_000_000;
    constant SCAN_FREQ_HZ_C : positive := 1_000;
    constant ROW_COUNT_C : positive := 4;
    constant COLUMN_COUNT_C : positive := 3;
    constant KEY_CODE_WIDTH_C : positive := 4;
    constant MATRIX_ACTIVE_LEVEL_C : std_logic := '0';

    constant CLK_PERIOD_C : time := 1 sec / CLK_FREQ_HZ_C;

    signal clk_s : std_logic := '0';
    signal nRst_s : std_logic := '1';

    signal rows_s : std_logic_vector(0 to ROW_COUNT_C - 1);
    signal columns_s : std_logic_vector(0 to COLUMN_COUNT_C - 1);
    signal key_code_s : std_logic_vector(KEY_CODE_WIDTH_C - 1 downto 0);
    signal n_key_code_s : std_logic_vector(KEY_CODE_WIDTH_C - 1 downto 0);

begin
    clk_s <= not clk_s after CLK_PERIOD_C / 2;
    key_code_s <= not n_key_code_s;

    dut : entity work.keyboard
        generic map(
            CLK_FREQ_HZ_G         => CLK_FREQ_HZ_C,
            SCAN_FREQ_HZ_G        => SCAN_FREQ_HZ_C,
            ROW_COUNT_G           => ROW_COUNT_C,
            COLUMN_COUNT_G        => COLUMN_COUNT_C,
            KEY_CODE_WIDTH_G      => KEY_CODE_WIDTH_C,
            MATRIX_ACTIVE_LEVEL_G => MATRIX_ACTIVE_LEVEL_C
        )
        port map(
            clk_i  => clk_s,
            nRst_i => nRst_s,
            rows_i => rows_s,

            columns_o    => columns_s,
            n_key_code_o => n_key_code_s
        );

    tester : entity work.keyboard_tester(behavioral)
        generic map(
            CLK_FREQ_HZ_G         => CLK_FREQ_HZ_C,
            SCAN_FREQ_HZ_G        => SCAN_FREQ_HZ_C,
            ROW_COUNT_G           => ROW_COUNT_C,
            COLUMN_COUNT_G        => COLUMN_COUNT_C,
            KEY_CODE_WIDTH_G      => KEY_CODE_WIDTH_C,
            MATRIX_ACTIVE_LEVEL_G => MATRIX_ACTIVE_LEVEL_C
        )
        port map(
            clk_i      => clk_s,
            columns_i  => columns_s,
            key_code_i => key_code_s,

            nRst_o => nRst_s,
            rows_o => rows_s
        );
end architecture behavioral;
