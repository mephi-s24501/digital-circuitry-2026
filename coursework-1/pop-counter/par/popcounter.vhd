library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity popcounter is
port(
    data_i     : in  std_logic_vector(15 downto 0);
    clk        : in  std_logic;
    nRst       : in  std_logic;
    quantity_o : out std_logic_vector(4 downto 0);
    done_o     : out std_logic
);
end entity;


architecture synth of popcounter is

function count_tree(
    value : std_logic_vector;
    left  : integer;
    right : integer
) return std_logic_vector is

    variable middle_v    : integer;
    variable left_sum_v  : std_logic_vector(4 downto 0);
    variable right_sum_v : std_logic_vector(4 downto 0);

begin
    if left = right then
        return "0000" & value(left);
    end if;

    middle_v := (left + right) / 2;

    left_sum_v  := count_tree(value, left, middle_v);
    right_sum_v := count_tree(value, middle_v + 1, right);

    return left_sum_v + right_sum_v;
end function;


signal data_r         : std_logic_vector(15 downto 0);
signal quantity_r     : std_logic_vector(4 downto 0);
signal result_valid_r : std_logic;

begin

    quantity_o <= quantity_r;
    done_o <= result_valid_r when data_i = data_r else '0';
    process(clk, nRst)
    begin
        if nRst = '0' then
            data_r         <= (others => '0');
            quantity_r     <= (others => '0');
            result_valid_r <= '0';
        elsif rising_edge(clk) then
            data_r         <= data_i;
            quantity_r     <= count_tree(data_i, 0, 15);
            result_valid_r <= '1';
        end if;
    end process;

end architecture;