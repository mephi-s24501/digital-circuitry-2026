library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity keyboard is
    generic (
        CLK_FREQ_HZ_G  : positive := 50_000_000;
        SCAN_FREQ_HZ_G : positive := 1_000;

        ROW_COUNT_G           : positive  := 4;
        COLUMN_COUNT_G        : positive  := 3;
        KEY_CODE_WIDTH_G      : positive  := 4;
        MATRIX_ACTIVE_LEVEL_G : std_logic := '0'
    );

    port (
        clk_i  : in std_logic;
        nRst_i : in std_logic;

        rows_i    : in std_logic_vector (0 to ROW_COUNT_G - 1);
        columns_o : out std_logic_vector (0 to COLUMN_COUNT_G - 1);

        n_key_code_o : out std_logic_vector (KEY_CODE_WIDTH_G - 1 downto 0)
    );
end entity keyboard;

architecture rtl of keyboard is
    -- Should be declared before SCAN_COUNTER_WIDTH_C (analysis & elaboration)
    function ceil_log2 (
        value : positive
    )
        return positive is
        variable v : natural := value - 1;
        variable width_v : positive := 1;
    begin
        while v > 1 loop
            v := v / 2;
            width_v := width_v + 1;
        end loop;

        return width_v;
    end function;

    constant SCAN_DIV_C : positive := CLK_FREQ_HZ_G / SCAN_FREQ_HZ_G;
    constant SCAN_COUNTER_WIDTH_C : positive := ceil_log2(SCAN_DIV_C);
    constant SCAN_COUNTER_MAX_C : std_logic_vector(SCAN_COUNTER_WIDTH_C - 1 downto 0) := conv_std_logic_vector(SCAN_DIV_C - 1, SCAN_COUNTER_WIDTH_C);

    -- Matrix logic constants
    constant MATRIX_INACTIVE_LEVEL_C : std_logic := not MATRIX_ACTIVE_LEVEL_G;
    constant ROWS_INACTIVE_C : std_logic_vector(rows_i'range) := (others => MATRIX_INACTIVE_LEVEL_C);
    constant COLUMNS_INACTIVE_C : std_logic_vector(columns_o'range) := (others => MATRIX_INACTIVE_LEVEL_C);
    constant FIRST_ACTIVE_COLUMN_C : std_logic_vector(columns_o'range) := (0 => MATRIX_ACTIVE_LEVEL_G, others => MATRIX_INACTIVE_LEVEL_C);

    constant NO_KEY_CODE_C : std_logic_vector(n_key_code_o'range) := (others => '0');

    -- FSM states
    type kbd_state_type is (
        init_state,
        scan_state,
        wait_release_state
    );

    -- Go to the next scanned column
    function rotate_columns (
        columns : std_logic_vector
    )
        return std_logic_vector is
    begin
        if columns'length = 1 then
            return columns;
        end if;

        return columns(columns'right) & columns(columns'left to columns'right - 1);
    end function;

    function line_to_index (
        value : std_logic_vector
    )
        return natural is
        variable index_v : natural range 0 to value'length - 1 := 0;
    begin
        for i in value'range loop
            if value(i) = MATRIX_ACTIVE_LEVEL_G then
                index_v := i;
            end if;
        end loop;

        return index_v;
    end function;

    -- key_code = column_count * row_idx + column_idx + 1
    function encode_key (
        rows    : std_logic_vector;
        columns : std_logic_vector
    )
        return std_logic_vector is
        variable key_num_v : natural range 0 to ROW_COUNT_G * COLUMN_COUNT_G;
    begin
        key_num_v :=
            columns'length * line_to_index(rows)
            + line_to_index(columns)
            + 1;

        return conv_std_logic_vector(key_num_v, n_key_code_o'length);
    end function;

    signal state_r : kbd_state_type;
    signal scan_counter_r : std_logic_vector(SCAN_COUNTER_WIDTH_C - 1 downto 0);
    signal scan_enable_r : std_logic;

    signal columns_r : std_logic_vector(columns_o'range);
    signal rows_meta_r : std_logic_vector(rows_i'range);
    signal rows_sync_r : std_logic_vector(rows_i'range);
    signal key_code_r : std_logic_vector(n_key_code_o'range);

begin
    -- Configuration checks

    assert MATRIX_ACTIVE_LEVEL_G = '0' or MATRIX_ACTIVE_LEVEL_G = '1'
    report "MATRIX_ACTIVE_LEVEL_G must be '0' or '1'"
        severity failure;

    assert 2 ** KEY_CODE_WIDTH_G >= ROW_COUNT_G * COLUMN_COUNT_G + 1
    report "Key code width is too small for the number of keys"
        severity failure;

    assert CLK_FREQ_HZ_G mod SCAN_FREQ_HZ_G = 0
    report "Scan frequency must divide clock frequency"
        severity failure;

    assert SCAN_DIV_C >= 3
    report "Scan period is too short for row 2-stage synchronization"
        severity failure;

    columns_o <= columns_r;
    n_key_code_o <= not key_code_r;

    -- Synchronize key inputs to mitigate metastability before processing
    sync_rows : process (clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            rows_meta_r <= ROWS_INACTIVE_C;
            rows_sync_r <= ROWS_INACTIVE_C;

        elsif rising_edge(clk_i) then
            rows_meta_r <= rows_i;
            rows_sync_r <= rows_meta_r;
        end if;
    end process sync_rows;

    -- Generate scan enable pulses at SCAN_FREQ_HZ_G
    scan_timer : process (clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            scan_counter_r <= SCAN_COUNTER_MAX_C;
            scan_enable_r <= '0';

        elsif rising_edge(clk_i) then
            if scan_counter_r = conv_std_logic_vector(0, scan_counter_r'length) then
                scan_counter_r <= SCAN_COUNTER_MAX_C;
                scan_enable_r <= '1';
            else
                scan_counter_r <= scan_counter_r - 1;
                scan_enable_r <= '0';
            end if;
        end if;
    end process scan_timer;

    switch_state : process (clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            state_r <= init_state;

        elsif rising_edge(clk_i) then
            if scan_enable_r = '1' then

                case state_r is
                    when init_state =>
                        state_r <= scan_state;

                    when scan_state =>
                        if rows_sync_r /= ROWS_INACTIVE_C then
                            state_r <= wait_release_state;
                        end if;

                    when wait_release_state =>
                        if rows_sync_r = ROWS_INACTIVE_C then
                            state_r <= scan_state;
                        end if;

                    when others =>
                        state_r <= init_state;
                end case;

            end if;
        end if;
    end process switch_state;

    assign_signals : process (clk_i, nRst_i)
    begin
        if nRst_i = '0' then
            columns_r <= COLUMNS_INACTIVE_C;
            key_code_r <= NO_KEY_CODE_C;

        elsif rising_edge(clk_i) then
            if scan_enable_r = '1' then

                if state_r = init_state then
                    columns_r <= FIRST_ACTIVE_COLUMN_C;
                elsif state_r = scan_state then
                    if rows_sync_r = ROWS_INACTIVE_C then
                        columns_r <= rotate_columns(columns_r);
                    end if;
                end if;

                if state_r = scan_state then
                    if rows_sync_r /= ROWS_INACTIVE_C then
                        key_code_r <= encode_key(rows_sync_r, columns_r);
                    end if;
                elsif state_r = wait_release_state then
                    if rows_sync_r = ROWS_INACTIVE_C then
                        key_code_r <= NO_KEY_CODE_C;
                    end if;

                end if;
            end if;
        end if;
    end process assign_signals;
end architecture;
