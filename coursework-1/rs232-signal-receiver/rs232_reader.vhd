library ieee;
  use ieee.std_logic_1164.all;

entity rs232_reader is
  generic (
    n        : natural;
    end_bits : natural
  );
  port (
    data_in_i  : in    std_logic;
    clki_i     : in    std_logic;
    sr_en_i    : in    std_logic;
    rst_ni     : in    std_logic;
    data_out_o : out   std_logic_vector(n - 1 downto 0);
    out_en_o   : out   std_logic;
    err_o      : out   std_logic
  );
end entity rs232_reader;

architecture rtl of rs232_reader is

  signal read_sr   : std_logic_vector(n + end_bits downto 0);

begin

  clock : process (clki_i, rst_ni) is
  begin

    if (rst_ni = '0') then
      read_sr    <= (others => '1');
      data_out_o <= (others => '0');
      out_en_o   <= '0';
      err_o      <= '1';
    elsif rising_edge(clki_i) then
      out_en_o <= '0';

      if (sr_en_i = '1') then
        read_sr <= read_sr(read_sr'high - 1 downto 0) & data_in_i;
      end if;

      if (read_sr(read_sr'high) = '0') then
        data_out_o <= read_sr(read_sr'high - 1 downto end_bits);
        if (read_sr(end_bits - 1 downto 0) = (end_bits - 1 downto 0 => '1')) then
          err_o <= '0';
        else
          err_o <= '1';
        end if;
        out_en_o <= '1';
        read_sr  <= (others => '1');
      end if;
    end if;

  end process clock;

end architecture rtl;
