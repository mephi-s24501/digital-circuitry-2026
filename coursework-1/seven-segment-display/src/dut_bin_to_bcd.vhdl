library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dut_bin_to_bcd is
  port (
    data_i : in  std_logic_vector(15 downto 0);
    bcd_o  : out std_logic_vector(15 downto 0)
  );
end entity dut_bin_to_bcd;

architecture rtl of dut_bin_to_bcd is
begin
  process (data_i)
    variable bin_v   : unsigned(15 downto 0);
    variable bcd20_v : unsigned(19 downto 0);
  begin
    bin_v   := unsigned(data_i);
    bcd20_v := (others => '0');

    for i in 15 downto 0 loop
      if bcd20_v(3 downto 0) > 4 then
        bcd20_v(3 downto 0) := bcd20_v(3 downto 0) + 3;
      end if;
      if bcd20_v(7 downto 4) > 4 then
        bcd20_v(7 downto 4) := bcd20_v(7 downto 4) + 3;
      end if;
      if bcd20_v(11 downto 8) > 4 then
        bcd20_v(11 downto 8) := bcd20_v(11 downto 8) + 3;
      end if;
      if bcd20_v(15 downto 12) > 4 then
        bcd20_v(15 downto 12) := bcd20_v(15 downto 12) + 3;
      end if;
      if bcd20_v(19 downto 16) > 4 then
        bcd20_v(19 downto 16) := bcd20_v(19 downto 16) + 3;
      end if;

      bcd20_v := bcd20_v(18 downto 0) & bin_v(i);
    end loop;

    if bcd20_v(19 downto 16) /= "0000" then
      bcd_o <= "1001100110011001";
    else
      bcd_o <= std_logic_vector(bcd20_v(15 downto 0));
    end if;
  end process;
end architecture rtl;
