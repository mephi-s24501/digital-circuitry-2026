library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;

entity rs232_clock is
  generic (
    counter_size   : natural;
    M_timeout_log2 : natural
  );
  port (
    data_i      : in  std_logic;
    rst_ni      : in  std_logic;
    clki_i      : in  std_logic;
    out_en_i    : in  std_logic;
    sr_en_o     : out std_logic;
    data_sync_o : out std_logic
  );
end entity rs232_clock;

architecture rtl of rs232_clock is

  type clock_fsm is (
    st_c_wait,  -- Waiting for calibration packet
    st_c_start, -- Calibrating
    st_idle,    -- Waiting for data packet
    st_data     -- Receiving data packet
  );

  signal state      : clock_fsm;
  signal up_count   : std_logic_vector(counter_size - 1 downto 0);
  signal down_count : std_logic_vector(counter_size - 2 downto 0);
  signal cal_count  : std_logic_vector(counter_size - 1 + M_timeout_log2 downto 0);
  signal divider2   : std_logic;
  signal data_meta  : std_logic;
  signal data_sync  : std_logic;

begin

  assert counter_size >= 2
    report "counter_size must be >= 2"
    severity failure;

  clock : process (clki_i, rst_ni) is
  begin

    if (rst_ni = '0') then
      state <= st_c_wait;
    elsif rising_edge(clki_i) then

      case state is

        when st_c_wait =>

          if (data_sync = '0') then
            state <= st_c_start;
          end if;

        when st_c_start =>

          if (data_sync = '1') then
            state <= st_idle;
          end if;

        when st_idle =>

          if (data_sync = '0') then
            state <= st_data;
          elsif (cal_count = 0) then
            state <= st_c_wait;
          end if;

        when st_data =>

          if (out_en_i = '1') then
            state <= st_idle;
          end if;

      end case;

    end if;

  end process clock;

  data_sync_o <= data_sync;

  signals : process (clki_i, rst_ni) is
  begin

    if (rst_ni = '0') then
      sr_en_o    <= '0';
      up_count   <= (others => '0');
      down_count <= (others => '0');
      cal_count  <= (others => '0');
      divider2   <= '1';
      data_meta  <= '1';
      data_sync  <= '1';
    elsif rising_edge(clki_i) then
      data_meta <= data_i;
      data_sync <= data_meta;

      if (state = st_c_wait) then
        up_count <= (others => '0');
      elsif (state = st_c_start) then
        up_count <= up_count + 1;
        assert up_count /= (up_count'range => '1')
          report "Overflow!!"
          severity failure;
      end if;

      if (state = st_c_wait) then
        down_count <= (others => '0');
      elsif (
        (state = st_c_start and data_sync = '1')
          or (state = st_idle)
          or (state = st_data and down_count = 1)
      ) then
        down_count <= up_count(counter_size - 1 downto 1);
      elsif (state = st_data) then
        down_count <= down_count - 1;
      end if;

      if (state = st_idle) then
        cal_count <= cal_count - 1;
      else
        cal_count <= up_count & (M_timeout_log2 downto 1 => '0');
      end if;

      if (state = st_data) then
        if (down_count = 1) then
          divider2 <= not divider2;
        end if;
      else
        divider2 <= '1';
      end if;

      if (state = st_data and divider2 = '1' and down_count = 1) then
        sr_en_o <= '1';
      else
        sr_en_o <= '0';
      end if;
    end if;

  end process signals;

end architecture rtl;
