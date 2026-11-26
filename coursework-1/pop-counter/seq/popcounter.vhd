library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity popcounter is
port(
	data_i: in std_logic_vector(15 downto 0);
	clk: in std_logic;
	nRst: in std_logic;
	quantity_o: out std_logic_vector(4 downto 0);
	done_o: out std_logic
	);
end;
architecture synth of popcounter is

function count(number: std_logic_vector(15 downto 0)) return std_logic_vector is
variable quantity_v: std_logic_vector(4 downto 0) := (others => '0');
begin
  for i in number'range loop
    if number(i) = '1' then
      quantity_v := quantity_v + 1;
    end if;
  end loop;
  return quantity_v;
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
            quantity_r     <= count(data_i);
            result_valid_r <= '1';
        end if;
    end process;

end architecture;
