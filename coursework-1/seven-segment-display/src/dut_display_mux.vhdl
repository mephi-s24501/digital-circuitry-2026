library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity dut_display_mux is
  generic (
    -- сколько тактов clk_i горит один разряд:
    -- 50 MHz / 50000 = 1 кГц на разряд, кадр 4 разряда = 250 Гц
    scan_div_g : integer := 50000
  );
  port (
    segments_i : in  std_logic_vector(27 downto 0);
    clk_i      : in  std_logic;
    nRst_li    : in  std_logic;
    seg_o      : out std_logic_vector(6 downto 0);
    digit_o    : out std_logic_vector(3 downto 0)
  );
end entity dut_display_mux;

architecture rtl of dut_display_mux is
  signal prescaler_r     : integer range 0 to scan_div_g - 1;
  signal digit_sel_count : std_logic_vector(1 downto 0);
  signal digit_onehot_s  : std_logic_vector(3 downto 0);
begin

  process (clk_i, nRst_li)
  begin
    if nRst_li = '0' then
      prescaler_r     <= 0;
      digit_sel_count <= (others => '0');
    elsif rising_edge(clk_i) then
      if prescaler_r = scan_div_g - 1 then
        prescaler_r     <= 0;
        digit_sel_count <= digit_sel_count + 1;
      else
        prescaler_r <= prescaler_r + 1;
      end if;
    end if;
  end process;

  with digit_sel_count select
    seg_o <= segments_i(6 downto 0)   when "00",
             segments_i(13 downto 7)  when "01",
             segments_i(20 downto 14) when "10",
             segments_i(27 downto 21) when others;

  with digit_sel_count select
    digit_onehot_s <= "0001" when "00",
                      "0010" when "01",
                      "0100" when "10",
                      "1000" when others;

  -- one-hot, active high: '1' selects the digit
  digit_o <= digit_onehot_s;

end architecture rtl;
