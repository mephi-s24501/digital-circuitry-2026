library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  use std.env.all;
  use std.textio.all;
  use work.Command_Display_Pkg.all;
  use work.Tb_Utils_Pkg.all;

entity Display_Driver_Tester is
  generic (
    CLK_PERIOD_G : time := 20 ns
  );
  port (
    clk_o          : out std_logic;
    busy_i         : in std_logic;
    load_o         : out std_logic;
    cmd_o          : out onfi_command_t;
    row_o          : out std_logic_vector(15 downto 0);
    col_o          : out std_logic_vector(15 downto 0);
    fb_rst_no      : out std_logic;
    display_rst_no : out std_logic;
    pgup_no        : out std_logic;
    pgdown_no      : out std_logic;
    shot_o         : out natural range 0 to 3;
    sda_io         : inout std_logic;
    scl_io         : inout std_logic
  );
end entity Display_Driver_Tester;

architecture sim of Display_Driver_Tester is
  constant GDDRAM_BYTES_C    : natural := 128 * 8;
  constant BTN_HOLD_CYCLES_C : natural := 10;
  constant LAST_SHOT_C       : natural := 3;

  signal clk_s  : std_logic            := '0';
  signal shot_s : natural range 0 to 3 := 0;

  -- Incremented by the monitor each time a full 1024-byte frame has been
  -- captured, so the stimulus can wait for a frame before moving the view.
  signal frame_cnt_s : natural range 0 to 15 := 0;

  -- Block until the monitor has captured at least n frames.
  procedure wait_frames (
    signal clk : in std_logic;
    signal cnt : in natural;
    constant n : in natural
  ) is
  begin
    while cnt < n loop
      wait until rising_edge(clk);
    end loop;
  end procedure wait_frames;

  -- One exported file per captured frame.  Shot 0 is the live view before
  -- any button press; the rest are the frames drawn after each press.
  function img_name (
    constant shot : in natural
  ) return string is
  begin
    case shot is
      when 1 => return "i2c_pgup.hex";
      when 2 => return "i2c_pgdown1.hex";
      when 3 => return "i2c_pgdown2.hex";
      when others => return "i2c.hex";
    end case;
  end function img_name;

  -- Active-low button press: hold long enough for the DUT synchronizer,
  -- then release and let it settle before the next press.
  procedure press_button (
    signal clk : in  std_logic;
    signal btn : out std_logic;
    constant n : in  natural
  ) is
  begin
    btn <= '0';
    wait_cycles(clk, n);
    btn <= '1';
    wait_cycles(clk, n);
  end procedure press_button;
begin

  clk_s  <= not clk_s after CLK_PERIOD_G / 2;
  clk_o  <= clk_s;
  shot_o <= shot_s;

  -- Fill the ring while the driver is held in reset, then release it and
  -- write the page that becomes the live view.  The driver draws once, so
  -- the exported frame is deterministic.
  stimulus : process is
  begin
    fb_rst_no      <= '0';
    display_rst_no <= '0';
    pgup_no        <= '1';
    pgdown_no      <= '1';
    shot_s         <= 0;
    wait_cycles(clk_s, 5);
    fb_rst_no      <= '1';

    wait_cycles(clk_s, 2);

    send_page(clk_s, load_o, cmd_o, row_o, col_o, busy_i,
              ONFI_READ, x"1111", x"0012");

    send_page(clk_s, load_o, cmd_o, row_o, col_o, busy_i,
              ONFI_PAGE_PROGM, x"2222", x"1234");

    display_rst_no <= '1';
    wait_cycles(clk_s, 2);

    send_page(clk_s, load_o, cmd_o, row_o, col_o, busy_i,
              ONFI_RESET_SYNC, x"3333", x"3456");

    wait_frames(clk_s, frame_cnt_s, 1);

    -- Move one page back.  A single PgUp only leaves one older page, so a
    -- new command page is sent afterwards while the view is detached: live
    -- moves on but the view stays, which gives the two PgDown presses two
    -- distinct steps to walk (back to live).
    shot_s <= 1;
    press_button(clk_s, pgup_no, BTN_HOLD_CYCLES_C);
    wait_frames(clk_s, frame_cnt_s, 2);

    send_page(clk_s, load_o, cmd_o, row_o, col_o, busy_i,
              ONFI_RESET, x"4444", x"5678");

    shot_s <= 2;
    press_button(clk_s, pgdown_no, BTN_HOLD_CYCLES_C);
    wait_frames(clk_s, frame_cnt_s, 3);

    shot_s <= 3;
    press_button(clk_s, pgdown_no, BTN_HOLD_CYCLES_C);

    wait;
  end process stimulus;

  -- Decodes SCL/SDA, skips the address and ACK bits, and dumps the payload
  -- of the 0x40 data transaction.
  monitor : process (sda_io, scl_io) is
    file     img_f : text;
    variable l_v   : line;

    variable bit_cnt_v  : natural range 0 to 7         := 0;
    variable byte_v     : std_logic_vector(7 downto 0) := (others => '0');
    variable byte_cnt_v : natural                      := 0;
    variable data_cnt_v : natural                      := 0;
    variable shot_v     : natural range 0 to 3         := 0;
    variable in_data_v  : boolean                      := false;
    variable in_ack_v   : boolean                      := false;
  begin
    if rising_edge(scl_io) then
      if in_ack_v then
        -- ACK clock: bit already handled on the 8th rising edge.
        in_ack_v := false;
      else
        byte_v := byte_v(6 downto 0) & To_X01(sda_io);

        if (bit_cnt_v /= 7) then
          bit_cnt_v := bit_cnt_v + 1;
        else
          bit_cnt_v := 0;
          in_ack_v  := true;

          if (byte_cnt_v = 0) then
            null; -- slave address
          elsif (byte_cnt_v = 1) then
            if (byte_v = x"40") then
              shot_v     := shot_s;
              file_open(img_f, img_name(shot_v), WRITE_MODE);
              in_data_v  := true;
              data_cnt_v := 0;
            end if;
          elsif (in_data_v and data_cnt_v < GDDRAM_BYTES_C) then
            write(l_v, to_hstring(byte_v));
            writeline(img_f, l_v);
            data_cnt_v := data_cnt_v + 1;

            if (data_cnt_v = GDDRAM_BYTES_C) then
              file_close(img_f);
              in_data_v   := false;
              frame_cnt_s <= frame_cnt_s + 1;
              report "Display_Driver_Tester: wrote " & integer'image(GDDRAM_BYTES_C) &
                     " bytes to " & img_name(shot_v)
                severity note;

              if (shot_v = LAST_SHOT_C) then
                finish;
              end if;
            end if;
          end if;

          byte_cnt_v := byte_cnt_v + 1;
        end if;
      end if;
    end if;

    -- START/STOP change SDA while SCL is high; only START starts a byte.
    if sda_io'event and To_X01(scl_io) = '1' then
      if (To_X01(sda_io) = '1' and in_data_v) then
        file_close(img_f);
        in_data_v   := false;
        frame_cnt_s <= frame_cnt_s + 1;
        report "Display_Driver_Tester: exported " & integer'image(data_cnt_v) &
               " bytes to " & img_name(shot_v)
          severity note;

        if (data_cnt_v /= GDDRAM_BYTES_C) then
          report "Display_Driver_Tester: frame ended after " & integer'image(data_cnt_v) &
                 " bytes, expected " & integer'image(GDDRAM_BYTES_C)
            severity warning;
        end if;

        if (shot_v = LAST_SHOT_C) then
          finish;
        end if;
      end if;

      bit_cnt_v  := 0;
      in_ack_v   := false;
      byte_cnt_v := 0;
      byte_v     := (others => '0');
      if To_X01(sda_io) = '0' then
        in_data_v := false;
      end if;
    end if;
  end process monitor;

  watchdog : process is
  begin
    wait for 200 ms;
    assert false
      report "Tb_Display_Driver: timeout waiting for the image frame"
      severity failure;
    finish;
  end process watchdog;


end architecture sim;
