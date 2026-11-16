--
-- VHDL Architecture SSD_TestStation.i2c_master_flow_mmode.behavior
--
-- Created:
--          by - Valery.UNKNOWN (MOIRAINE)
--          at - 17:30:12 01.09.2020
--
-- using Mentor Graphics HDL Designer(TM) 2018.2 (Build 19)
--
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;

ENTITY i2c_master_flow_mmode IS
   GENERIC( 
      input_clk : INTEGER := 40_000_000;      --input clock speed from user logic in Hz
      bus_clk   : INTEGER := 150_000
   );
   PORT( 
      addr       : IN     std_logic_vector (6 DOWNTO 0);          --address of target slave
      clk        : IN     STD_LOGIC;                              --system clock
      data_wr    : IN     std_logic_vector (7 DOWNTO 0);          --data to write to slave
      ena        : IN     STD_LOGIC;                              --latch in command
      nRst       : IN     STD_LOGIC;                              --active low reset
      rw         : IN     STD_LOGIC;                              --'0' is write, '1' is read
      busy       : OUT    STD_LOGIC;                              --indicates transaction in progress
      idle       : OUT    STD_LOGIC;                              --indicates Ready FSM
      data_rd    : OUT    std_logic_vector (7 DOWNTO 0);          --data read from slave
      scl        : INOUT  STD_LOGIC;                              --serial clock output of i2c bus
      sda        : INOUT  STD_LOGIC;                              --serial data output of i2c bus
      ack_error  : BUFFER STD_LOGIC;                              --flag if improper acknowledge from slave
      mode       : IN     std_logic_vector (1 DOWNTO 0) := "00";  --work mode SMBus
      data_valid : OUT    std_logic;                              --readed data validity strobe
      ack        : OUT    std_logic                               --indicates ACK1 or ACK2 statets  FSM
   );

-- Declarations

END i2c_master_flow_mmode ;

--
ARCHITECTURE behavior OF i2c_master_flow_mmode IS
  CONSTANT divider  :  INTEGER := (input_clk/bus_clk)/4; --number of clocks in 1/4 cycle of scl
  --
  constant mode_652 : std_logic_vector(1 downto 0) := "00";  -- mode 6.5.2-4 subsections SMBus 3.1 Spec
  constant mode_655 : std_logic_vector(1 downto 0) := "01";  -- mode 6.5.5-6 subsections SMBus 3.1 Spec
  constant mode_657 : std_logic_vector(1 downto 0) := "10";  -- mode 6.5.7 subsection SMBus 3.1 Spec
  --
  TYPE machine IS(
    ready,
    start,
    command,
    slv_ack1,
    wr,
    rd,
    slv_ack2,
    mstr_ack,
    stop); --needed states
  --
  SIGNAL i2c_state     : machine;                        --state machine
  --
  SIGNAL data_clk      : STD_LOGIC;                      --data clock for sda
  SIGNAL data_clk_prev : STD_LOGIC;                      --data clock during previous system clock
  SIGNAL scl_clk       : STD_LOGIC;                      --constantly running internal scl
  SIGNAL scl_ena       : STD_LOGIC := '0';               --enables internal scl to output
  SIGNAL sda_int       : STD_LOGIC := '1';               --internal sda
  SIGNAL sda_ena_n     : STD_LOGIC;                      --enables internal sda to output
  SIGNAL addr_rw       : STD_LOGIC_VECTOR(7 DOWNTO 0);   --latched in address and read/write
  SIGNAL data_tx       : STD_LOGIC_VECTOR(7 DOWNTO 0);   --latched in data to write to slave
  SIGNAL data_rx       : STD_LOGIC_VECTOR(7 DOWNTO 0);   --data received from slave
  SIGNAL bit_cnt       : INTEGER RANGE 0 TO 7 := 7;      --tracks bit number in transaction
  SIGNAL stretch       : STD_LOGIC := '0';               --identifies if slave is stretching scl
  --
  signal data_valid_r : std_logic;
--  signal ack_r : std_logic;
  --
BEGIN
  --set sda output
  WITH i2c_state SELECT
    sda_ena_n <= data_clk_prev  WHEN start,     --generate start condition
    NOT data_clk_prev           WHEN stop,      --generate stop condition
    sda_int                     WHEN OTHERS;    --set to internal sda signal    
      
  --set scl and sda outputs
  scl <= '0' WHEN (scl_ena = '1' AND scl_clk = '0') ELSE 'Z';
  sda <= '0' WHEN sda_ena_n = '0' ELSE 'Z';
  --
  idle <= '1' when (i2c_state = Ready) else '0';
  data_valid <= data_valid_r;
  ack <= '1' when (i2c_state = slv_ack1 or i2c_state = slv_ack2) else
         '0';
-------------------------------------------------------------------------------
--generate the timing for the bus clock (scl_clk) and the data clock (data_clk)
-- purpose: processing 
-- type   : sequential
-- inputs : Clk, nRst, 
-- outputs: 
PROCESS(clk, nRst)
  VARIABLE count  :  INTEGER RANGE 0 TO divider*4;  --timing for clock generation
BEGIN
  IF(nRst = '0') THEN                --reset asserted
    stretch <= '0';
    count := 0;
    data_clk_prev <= '1';
    scl_clk <= '1';
    data_clk <= '0';
    stretch <= '0';
  ELSIF(clk'EVENT AND clk = '1') THEN
    --
    data_clk_prev <= data_clk;          --store previous value of data clock
    --
    IF(count = divider*4-1) THEN        --end of timing cycle
      count := 0;                       --reset timer
    ELSIF(stretch = '0') THEN           --clock stretching from slave not detected
      count := count + 1;               --continue clock generation timing
    END IF;
    --
    if (count >= 0 and count < divider) then --first 1/4 cycle of clocking
      scl_clk <= '0';
      data_clk <= '0';
    elsif (count >= divider and count < divider*2) then --second 1/4 cycle of clocking
      scl_clk <= '0';
      data_clk <= '1';
    elsif (count >= divider*2 and count < divider*3) then --third 1/4 cycle of clocking
      scl_clk <= '1';                 --release scl
      data_clk <= '1';
    else   --last 1/4 cycle of clocking
      scl_clk <= '1';
      data_clk <= '0';
    end if;
    --
    if (count >= divider*2 and count <= divider*3-1) then
      IF(scl = '0') THEN              --detect if slave is stretching clock
        stretch <= '1';
      ELSE
        stretch <= '0';
      END IF;
    end if;
    --
  END IF;
END PROCESS;
-------------------------------------------------------------------------------
-- purpose: processing internal regs
-- type   : sequential
-- inputs : Clk, nRst
-- outputs: 
clocked: process (Clk, nRst)
begin  -- process clocked
  if (nRst = '0') then                   -- asynchronous reset (active low)
    busy <= '0';                         --indicate not available
    scl_ena <= '0';                      --sets scl high impedance
    sda_int <= '0';                      --sets sda high impedance
    ack_error <= '0';                    --clear acknowledge error flag
    bit_cnt <= 7;                        --restarts data bit counter
    addr_rw <= (others => '0');          --clear addr reg
    data_rd <= (others => '0');          --clear data read port
    data_tx <= (others => '0');          --clear data transmit port
    data_rx <= (others => '0');          --clear data receive port
    data_valid_r <= '0';
  elsif (Clk'event and Clk = '1') then    -- rising clock edge
    --
    if(data_clk = '1' AND data_clk_prev = '0') then  --data clock rising edge
      --
      if (i2c_state = rd) then
        if (bit_cnt = 0) then
          data_rd <= data_rx;
        end if;
      end if;
      --
      if (((i2c_state = command or i2c_state = wr) and bit_cnt = 0) or
          (i2c_state = slv_ack1 and addr_rw(0) = '1') or
          (i2c_state = rd and bit_cnt = 0 and (ena = '0' or addr_rw /= addr & rw)) or
          (i2c_state = mstr_ack and ena = '1' and addr_rw = addr & rw)) then
        sda_int <= '1';
      elsif (i2c_state = rd and bit_cnt = 0 and ena = '1' and addr_rw = addr & rw) then
--      elsif ((i2c_state = rd and bit_cnt = 0 and ena = '1' and addr_rw = addr & rw) or
--             (i2c_state = mstr_ack and ena = '0')) then
        sda_int <= '0';
      else
        if (i2c_state = start or i2c_state = command) then
          sda_int <= addr_rw(7);
        elsif (i2c_state = slv_ack1 and addr_rw(0) = '0') then
          sda_int <= data_tx(7);
        elsif (i2c_state = wr) then
          sda_int <= data_tx(6);
        elsif (i2c_state = slv_ack2 and ena = '1' and addr_rw = addr & rw) then
          sda_int <= data_wr(7);
        end if;
      end if;
      --
      if (bit_cnt = 0) then
        bit_cnt <= 7;
      else
        if (i2c_state = command or i2c_state = wr or i2c_state = rd) then
          bit_cnt <= bit_cnt - 1;
        end if;
      end if;
      --
      if ((i2c_state = Ready or i2c_state = slv_ack2 or i2c_state = mstr_ack) and ena = '1') then
        addr_rw <= addr & rw;
      elsif (i2c_state = start or i2c_state = command) then
        if (bit_cnt /= 0) then
          addr_rw(0) <= addr_rw(7);
          for i in 7 downto 1 loop
            addr_rw(i) <= addr_rw(i-1);
          end loop;  -- i
        end if;
      end if;
      --
      if ((i2c_state = Ready or i2c_state = slv_ack2 or i2c_state = mstr_ack) and ena = '1') then
        data_tx <= data_wr;
      elsif (i2c_state = wr) then
        data_tx(0) <= data_tx(7);
        for i in 7 downto 1 loop
          data_tx(i) <= data_tx(i-1);
        end loop;  -- i
      end if;
      --
      if ((i2c_state = Ready and ena = '1') or
          i2c_state = wr or i2c_state = rd) then
        busy <= '1';
      elsif (((i2c_state = slv_ack2 or i2c_state = mstr_ack) and ena = '1') or
             i2c_state = Stop) then
        busy <= '0';
      end if;
      --
    elsif(data_clk = '0' AND data_clk_prev = '1') then  --data clock falling edge
      --
      if (i2c_state = Start) then
        scl_ena <= '1';
      elsif (i2c_state = Stop) then
        scl_ena <= '0';
      end if;
      --
      if (i2c_state = Start) then
        ack_error <= '0';
      else
        if ((sda /= '0' or ack_error = '1') and
            (i2c_state = slv_ack1 or i2c_state = slv_ack2)) then
          ack_error <= '1';
        end if;
      end if;
      --
      if (i2c_state = rd) then
        data_rx(bit_cnt) <= sda;
      end if;
      --
    else  --any clock position
      --
      if (i2c_state = mstr_ack and ena = '0') then
        sda_int <= '1';                 -- end data block
      end if;
      --
    end if;
    --
    if (i2c_state = rd) then
      if(data_clk = '1' AND data_clk_prev = '0') then  --data clock rising edge
        if (bit_cnt = 0) then
          data_valid_r <= '1';
        end if;
      end if;
    else  
      data_valid_r <= '0';
    end if;
    --
  end if;
end process clocked;
-------------------------------------------------------------------------------
-- purpose: processing I2C Master FSM
-- type   : sequential
-- inputs : Clk, nRst, i2c_state
-- outputs: i2c_state
i2cstate: process (Clk, nRst)
begin  -- process i2cstate
  if (nRst = '0') then                    -- asynchronous reset (active low)
    i2c_state <= Ready;
  elsif (Clk'event and Clk = '1') then    -- rising clock edge
    if(data_clk = '1' AND data_clk_prev = '0') then  --data clock rising edge
      case i2c_state is
        when Ready =>
          if (ena = '1') then
            i2c_state <= Start;
          end if;
        when Start =>
          i2c_state <= command;
        when command =>
          if (bit_cnt = 0) then
            i2c_state <= slv_ack1;
          end if;
        when slv_ack1 =>
          if (addr_rw(0) = '0') then
            i2c_state <= wr;
          else  
            i2c_state <= rd;
          end if;
        when wr =>
          if (bit_cnt = 0) then
            i2c_state <= slv_ack2;
          end if;
        when rd =>
          if (bit_cnt = 0) then
            i2c_state <= mstr_ack;
          end if;
        when slv_ack2 =>
          if (ena = '1') then
            if (addr_rw = addr & rw) then
              i2c_state <= wr;
            else  
              i2c_state <= Start;
            end if;
          else
            i2c_state <= Stop;
          end if;
        when mstr_ack =>
          if (ena = '1') then
            if (addr_rw = addr & rw) then
              i2c_state <= rd;
            else  
              i2c_state <= Start;
            end if;
          else
            i2c_state <= Stop;
          end if;
        when Stop =>
          i2c_state <= Ready;
        when others => null;
      end case;
    end if;
  end if;
end process i2cstate;
-------------------------------------------------------------------------------
END ARCHITECTURE behavior;

