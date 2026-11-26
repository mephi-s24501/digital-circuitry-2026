library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity code_lock_top is
    port (
        CLK12M   : in  std_logic;
        USER_BTN : in  std_logic;
        LED      : out std_logic_vector(7 downto 0)
    );
end entity code_lock_top;

architecture rtl of code_lock_top is

    constant DELAY : unsigned(23 downto 0) := to_unsigned(12000000, 24);

    signal btn_reset  : std_logic;
    signal reset      : std_logic;
    signal keys       : std_logic_vector(9 downto 0) := (others => '0');
    signal open_out   : std_logic;
    signal error_out  : std_logic;

    -- Автотестер
    signal delay_cnt  : unsigned(23 downto 0) := (others => '0');
    signal step       : unsigned(3 downto 0)  := (others => '0');
    signal test_reset : std_logic := '1';

    -- Счётчик нажатий для индикации
    signal keys_prev  : std_logic_vector(9 downto 0) := (others => '0');
    signal key_cnt    : unsigned(2 downto 0) := (others => '0');

    -- 1,2,3,4, пауза(step=4), затем 1,6,3,7
    type seq_type is array (0 to 8) of integer range 0 to 9;
    constant SEQ : seq_type := (1, 2, 3, 4, 0, 1, 6, 3, 7);

begin

    -- Активный высокий сброс от кнопки
    btn_reset <= '1' when USER_BTN = '0' else '0';
    reset <= '1' when USER_BTN = '0' or test_reset = '1' else '0';

    -- delay_cnt
    process(CLK12M, btn_reset)
    begin
        if btn_reset = '1' then
            delay_cnt <= (others => '0');
        elsif rising_edge(CLK12M) then
            if delay_cnt = DELAY then
                delay_cnt <= (others => '0');
            else
                delay_cnt <= delay_cnt + 1;
            end if;
        end if;
    end process;

    -- step
    process(CLK12M, btn_reset)
    begin
        if btn_reset = '1' then
            step <= (others => '0');
        elsif rising_edge(CLK12M) then
            if test_reset = '0' and delay_cnt = DELAY then
                if step < 9 then
                    step <= step + 1;
                else
                    step <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    -- keys (однотактный импульс на нужной клавише)
    process(CLK12M, btn_reset)
    begin
        if btn_reset = '1' then
            keys <= (others => '0');
        elsif rising_edge(CLK12M) then
            if test_reset = '1' then
                keys <= (others => '0');
            elsif delay_cnt = DELAY then
                if step < 9 then
                    keys <= (others => '0');
                    if step /= 4 then
                        keys(SEQ(to_integer(step))) <= '1';
                    end if;
                end if;
            elsif keys /= "0000000000" then
                keys <= (others => '0');
            end if;
        end if;
    end process;

    -- test_reset (пауза/работа автотестера)
    process(CLK12M, btn_reset)
    begin
        if btn_reset = '1' then
            test_reset <= '1';
        elsif rising_edge(CLK12M) then
            if test_reset = '1' then
                if delay_cnt = DELAY then
                    test_reset <= '0';
                end if;
            else
                if delay_cnt = DELAY and (step >= 9 or step = 4) then
                    test_reset <= '1';
                end if;
            end if;
        end if;
    end process;

    -- keys_prev
    process(CLK12M, reset)
    begin
        if reset = '1' then
            keys_prev <= (others => '0');
        elsif rising_edge(CLK12M) then
            keys_prev <= keys;
        end if;
    end process;

    -- key_cnt
    process(CLK12M, reset)
    begin
        if reset = '1' then
            key_cnt <= (others => '0');
        elsif rising_edge(CLK12M) then
            if keys /= "0000000000" and keys_prev = "0000000000" then
                if key_cnt < 4 then
                    key_cnt <= key_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    dut_inst : entity work.code_lock
        port map (
            clk       => CLK12M,
            reset     => reset,
            keys      => keys,
            open_out  => open_out,
            error_out => error_out
        );

    LED(0) <= '1' when key_cnt >= 1 else '0';
    LED(1) <= '1' when key_cnt >= 2 else '0';
    LED(2) <= '1' when key_cnt >= 3 else '0';
    LED(3) <= '1' when key_cnt >= 4 else '0';
    LED(4) <= open_out;
    LED(5) <= '0';
    LED(6) <= '0';
    LED(7) <= error_out;

end architecture rtl;