library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Svetofor is
	generic (
		G_CLK_FREQ_HZ : integer := 12_000_000;
    G_TICK_FREQ_HZ : integer := 1;
    G_BLINK_FREQ_HZ : integer := 2;

    G_DUR_RED_S : integer := 10;
    G_DUR_RED_YEL_S : integer := 2;
    G_DUR_GREEN_S : integer := 8;
    G_DUR_GREEN_BLK_S : integer := 3;
    G_DUR_YELLOW_S : integer := 2
  );
  port (
    Clk_i : in  std_logic;
    Reset_i : in  std_logic;
    Red_o : out std_logic;
    Yellow_o : out std_logic;
    Green_o : out std_logic
  );
end entity Svetofor;

architecture rtl of Svetofor is

  type State_Type is (
    S_RED,
    S_RED_YELLOW,
    S_GREEN,
    S_GREEN_BLINK,
    S_YELLOW
  );

  --Константы
	constant C_TICK_DIV : integer := G_CLK_FREQ_HZ / G_TICK_FREQ_HZ;
	constant C_BLINK_DIV : integer := G_CLK_FREQ_HZ / (2 * G_BLINK_FREQ_HZ);

  -- Длительности состояний (в тиках)
	constant C_DUR_RED_TICK : integer := G_DUR_RED_S * G_TICK_FREQ_HZ;
	constant C_DUR_RED_YEL_TICK : integer := G_DUR_RED_YEL_S * G_TICK_FREQ_HZ;
	constant C_DUR_GREEN_TICK : integer := G_DUR_GREEN_S * G_TICK_FREQ_HZ;
	constant C_DUR_GREEN_BLK_TICK : integer := G_DUR_GREEN_BLK_S * G_TICK_FREQ_HZ;
	constant C_DUR_YELLOW_TICK : integer := G_DUR_YELLOW_S * G_TICK_FREQ_HZ;

  -- Разрядности счетчиков
	constant C_TICK_W : integer := 24;  
	constant C_BLINK_W : integer := 22;  
	constant C_DUR_W : integer := 4;   

  -- сигналы первого делителя частоты (генерит тики)
	signal TickCnt_r : std_logic_vector(C_TICK_W - 1 downto 0) := conv_std_logic_vector(C_TICK_DIV - 1, C_TICK_W);
	signal Tick_r : std_logic := '0';

  -- сигналы второго делителя частоты (который генерит меандр)
	signal BlinkCnt_r : std_logic_vector(C_BLINK_W - 1 downto 0) := conv_std_logic_vector(C_BLINK_DIV - 1, C_BLINK_W);
	signal Blink_r : std_logic := '0';

  -- сигналы основного счетчика 
	signal DurCnt_r : std_logic_vector(C_DUR_W - 1 downto 0) := conv_std_logic_vector(C_DUR_RED_TICK, C_DUR_W);
	signal NextValue_r : std_logic_vector(C_DUR_W - 1 downto 0) := conv_std_logic_vector(C_DUR_RED_YEL_TICK, C_DUR_W);
	signal NewCycle_r : std_logic := '0';
	
  -- сигнал состояния
	signal State_r : State_Type := S_RED;

begin
  P_COUNTERS : process (Clk_i, Reset_i)
  begin
    if Reset_i = '0' then
      TickCnt_r  <= conv_std_logic_vector(C_TICK_DIV - 1, C_TICK_W);
      Tick_r     <= '0';
      BlinkCnt_r <= conv_std_logic_vector(C_BLINK_DIV - 1, C_BLINK_W);
      Blink_r    <= '0';
      DurCnt_r   <= conv_std_logic_vector(C_DUR_RED_TICK, C_DUR_W);
      NextValue_r <= conv_std_logic_vector(C_DUR_RED_YEL_TICK, C_DUR_W);
      NewCycle_r <= '0';
    elsif rising_edge(Clk_i) then

      -- первый делитель частоты (тики)
      if TickCnt_r = conv_std_logic_vector(0, C_TICK_W) then
        TickCnt_r <= conv_std_logic_vector(C_TICK_DIV - 1, C_TICK_W);
      else
        TickCnt_r <= TickCnt_r - 1;
      end if;

      if TickCnt_r = conv_std_logic_vector(0, C_TICK_W) then
        Tick_r <= '1';
      else
        Tick_r <= '0';
      end if;

      -- второй делитель частоты (меандр)
      if BlinkCnt_r = conv_std_logic_vector(0, C_BLINK_W) then
        BlinkCnt_r <= conv_std_logic_vector(C_BLINK_DIV - 1, C_BLINK_W);
      else
        BlinkCnt_r <= BlinkCnt_r - 1;
      end if;

      if BlinkCnt_r = conv_std_logic_vector(0, C_BLINK_W) then
        Blink_r <= not Blink_r;
      end if;

      -- основной счетчик

      if NewCycle_r = '1' then
        if State_r = S_RED then
          NextValue_r <= conv_std_logic_vector(C_DUR_GREEN_TICK, C_DUR_W);
        elsif State_r = S_RED_YELLOW then
          NextValue_r <= conv_std_logic_vector(C_DUR_GREEN_BLK_TICK, C_DUR_W);
        elsif State_r = S_GREEN then
          NextValue_r <= conv_std_logic_vector(C_DUR_YELLOW_TICK, C_DUR_W);
        elsif State_r = S_GREEN_BLINK then
          NextValue_r <= conv_std_logic_vector(C_DUR_RED_TICK, C_DUR_W);
        else
          NextValue_r <= conv_std_logic_vector(C_DUR_RED_YEL_TICK, C_DUR_W);
        end if;
      end if;

      if DurCnt_r = conv_std_logic_vector(0, C_DUR_W) then
        DurCnt_r <= NextValue_r;
      elsif Tick_r = '1' then
        DurCnt_r <= DurCnt_r - 1;
      end if;

      if DurCnt_r = conv_std_logic_vector(0, C_DUR_W) then
        NewCycle_r <= '1';
      else
        NewCycle_r <= '0';
      end if;

    end if;
  end process P_COUNTERS;


  P_FSM : process (Clk_i, Reset_i)
  begin
    if Reset_i = '0' then
      State_r <= S_RED;
    elsif rising_edge(Clk_i) then

      if NewCycle_r = '1' then
        case State_r is
          when S_RED  => State_r <= S_RED_YELLOW;
          when S_RED_YELLOW  => State_r <= S_GREEN;
          when S_GREEN => State_r <= S_GREEN_BLINK;
          when S_GREEN_BLINK => State_r <= S_YELLOW;
          when S_YELLOW => State_r <= S_RED;
        end case;
      end if;

    end if;
  end process P_FSM;


  P_OUT : process (State_r, Blink_r)
	begin
    -- красный
    if (State_r = S_RED) or (State_r = S_RED_YELLOW) then
      Red_o <= '1';
    else
      Red_o <= '0';
    end if;

    -- желтый
    if (State_r = S_RED_YELLOW) or (State_r = S_YELLOW) then
      Yellow_o <= '1';
    else
      Yellow_o <= '0';
    end if;

		-- зеленый
    if State_r = S_GREEN then
      Green_o <= '1';
    elsif (State_r = S_GREEN_BLINK) and (Blink_r = '1') then
      Green_o <= '1';
    else
      Green_o <= '0';
    end if;

	end process P_OUT;

end architecture rtl;