library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity code_lock is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        keys      : in  std_logic_vector(9 downto 0);
        open_out  : out std_logic;
        error_out : out std_logic
    );
end entity code_lock;


architecture rtl of code_lock is
    signal digit       : std_logic_vector(3 downto 0);
    signal digit_valid : std_logic;

    signal digit0_reg : std_logic_vector(3 downto 0);
    signal digit1_reg : std_logic_vector(3 downto 0);
    signal digit2_reg : std_logic_vector(3 downto 0);
    signal digit3_reg : std_logic_vector(3 downto 0);

    signal digit_cnt : std_logic_vector(1 downto 0);

    signal code_correct : std_logic;
    signal open_out_reg : std_logic;
    signal error_out_reg : std_logic;

    type state_type is (
        IDLE,
        INPUT,
        CHECK,
        OPEN_STATE,
        ERROR_STATE
    );

    signal state : state_type;

    constant CODE0 : std_logic_vector(3 downto 0) := "0001";
    constant CODE1 : std_logic_vector(3 downto 0) := "0010";
    constant CODE2 : std_logic_vector(3 downto 0) := "0011";
    constant CODE3 : std_logic_vector(3 downto 0) := "0100";

begin
    open_out  <= open_out_reg;
    error_out <= error_out_reg;

    process(keys)
    begin
        digit       <= (others => '0');
        digit_valid <= '0';

        if keys(0) = '1' then
            digit       <= "0000";
            digit_valid <= '1';
        elsif keys(1) = '1' then
            digit       <= "0001";
            digit_valid <= '1';
        elsif keys(2) = '1' then
            digit       <= "0010";
            digit_valid <= '1';
        elsif keys(3) = '1' then
            digit       <= "0011";
            digit_valid <= '1';
        elsif keys(4) = '1' then
            digit       <= "0100";
            digit_valid <= '1';
        elsif keys(5) = '1' then
            digit       <= "0101";
            digit_valid <= '1';
        elsif keys(6) = '1' then
            digit       <= "0110";
            digit_valid <= '1';
        elsif keys(7) = '1' then
            digit       <= "0111";
            digit_valid <= '1';
        elsif keys(8) = '1' then
            digit       <= "1000";
            digit_valid <= '1';
        elsif keys(9) = '1' then
            digit       <= "1001";
            digit_valid <= '1';
        end if;
    end process;


    code_correct <= '1'
        when digit0_reg = CODE0 and
             digit1_reg = CODE1 and
             digit2_reg = CODE2 and
             digit3_reg = CODE3
        else '0';


    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    if digit_valid = '1' then
                        state <= INPUT;
                    end if;

                when INPUT =>
                    if digit_valid = '1' and digit_cnt = "11" then
                        state <= CHECK;
                    end if;

                when CHECK =>
                    if code_correct = '1' then
                        state <= OPEN_STATE;
                    else
                        state <= ERROR_STATE;
                    end if;

                when OPEN_STATE | ERROR_STATE =>
                    null;
            end case;
        end if;
    end process;


    process(clk, reset)
    begin
        if reset = '1' then
            open_out_reg  <= '0';
            error_out_reg <= '0';
        elsif rising_edge(clk) then
            if state = OPEN_STATE then
                open_out_reg <= '1';
            else
                open_out_reg <= '0';
            end if;

            if state = ERROR_STATE then
                error_out_reg <= '1';
            else
                error_out_reg <= '0';
            end if;
        end if;
    end process;


    process(clk, reset)
    begin
        if reset = '1' then
            digit0_reg <= (others => '0');
            digit1_reg <= (others => '0');
            digit2_reg <= (others => '0');
            digit3_reg <= (others => '0');
            digit_cnt  <= "00";
        elsif rising_edge(clk) then
            if state = IDLE and digit_valid = '1' then
                digit0_reg <= digit;
            elsif state = INPUT and digit_valid = '1' then
                case digit_cnt is
                    when "01" => digit1_reg <= digit;
                    when "10" => digit2_reg <= digit;
                    when "11" => digit3_reg <= digit;
                    when others => null;
                end case;
            end if;

            if (state = IDLE or state = INPUT) and digit_valid = '1' then
                digit_cnt <= std_logic_vector(unsigned(digit_cnt) + 1);
            end if;
        end if;
    end process;

end architecture rtl;
