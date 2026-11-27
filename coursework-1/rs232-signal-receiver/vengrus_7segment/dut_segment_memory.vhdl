library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dut_segment_memory is
  port (
    segments_i : in  std_logic_vector(27 downto 0);
    update_li  : in  std_logic;
    clk_i      : in  std_logic;
    nRst_li    : in  std_logic;
    segments_o : out std_logic_vector(27 downto 0)
  );
end entity dut_segment_memory;

architecture rtl of dut_segment_memory is
  constant wait_sz_c  : natural := 4;

  constant count_max_c : std_logic_vector(2 downto 0) :=
                          std_logic_vector(to_unsigned(wait_sz_c, 3));
  constant count_nul_c : std_logic_vector(2 downto 0) := (others => '0');

  signal update_sync1_r : std_logic;
  signal update_sync2_r : std_logic;
  signal update_prev_r  : std_logic;
  signal wait_count_r   : std_logic_vector(2 downto 0);
  signal segs_reg_r     : std_logic_vector(27 downto 0);
begin

  process (clk_i, nRst_li)
  begin
    if nRst_li = '0' then
      update_sync1_r <= '1';
      update_sync2_r <= '1';
      update_prev_r  <= '1';
      wait_count_r   <= count_nul_c;
      segs_reg_r     <= (others => '1');
    elsif rising_edge(clk_i) then
      update_sync1_r <= update_li;
      update_sync2_r <= update_sync1_r;
      update_prev_r  <= update_sync2_r;

      if update_prev_r = '1' and update_sync2_r = '0' then
        wait_count_r <= count_max_c;

      elsif wait_count_r /= count_nul_c then
        wait_count_r <= std_logic_vector(unsigned(wait_count_r) - 1);
        if unsigned(wait_count_r) = 1 then
          segs_reg_r <= segments_i;
        end if;
      end if;
    end if;
  end process;

  segments_o <= segs_reg_r;
end architecture rtl;
