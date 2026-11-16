library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  use std.env.all;
  use std.textio.all;
  use work.Onfi_Command_Pkg.all;
  use work.Tb_Utils_Pkg.all;

entity Display_Driver_Tester is
  port (
    clk_i          : in std_logic;
    busy_i         : in std_logic;
    load_o         : out std_logic;
    cmd_o          : out onfi_command_t;
    row_o          : out std_logic_vector(15 downto 0);
    col_o          : out std_logic_vector(15 downto 0);
    fb_rst_no      : out std_logic;
    display_rst_no : out std_logic;
    sda_io         : inout std_logic;
    scl_io         : inout std_logic
  );
end entity Display_Driver_Tester;

architecture sim of Display_Driver_Tester is
  constant GDDRAM_BYTES_C : natural := 128 * 8;
  constant IMG_FILE_C     : string  := "i2c.hex";
begin

  -- Fill the ring while the driver is held in reset, then release it and
  -- write the page that becomes the live view.  The driver draws once, so
  -- the exported frame is deterministic.
  stimulus : process is
  begin
    fb_rst_no      <= '0';
    display_rst_no <= '0';
    wait_cycles(clk_i, 5);
    fb_rst_no      <= '1';

    wait_cycles(clk_i, 2);

    send_page(clk_i, load_o, cmd_o, row_o, col_o, busy_i,
              ONFI_READ, x"0000", x"0000");

    send_page(clk_i, load_o, cmd_o, row_o, col_o, busy_i,
              ONFI_PAGE_PROGM, x"0012", x"0034");

    display_rst_no <= '1';
    wait_cycles(clk_i, 2);

    send_page(clk_i, load_o, cmd_o, row_o, col_o, busy_i,
              ONFI_RESET_SYNC, x"0000", x"0000");

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
              file_open(img_f, IMG_FILE_C, write_mode);
              in_data_v  := true;
              data_cnt_v := 0;
            end if;
          elsif (in_data_v and data_cnt_v < GDDRAM_BYTES_C) then
            write(l_v, to_hstring(byte_v));
            writeline(img_f, l_v);
            data_cnt_v := data_cnt_v + 1;

            if (data_cnt_v = GDDRAM_BYTES_C) then
              file_close(img_f);
              in_data_v := false;
              report "Tb_Display_Driver: wrote " & integer'image(GDDRAM_BYTES_C) &
                     " bytes to " & IMG_FILE_C
                severity note;
              finish;
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
        in_data_v := false;
        report "Tb_Display_Driver: exported " & integer'image(data_cnt_v) &
               " bytes to " & IMG_FILE_C
          severity note;

        if (data_cnt_v /= GDDRAM_BYTES_C) then
          report "Tb_Display_Driver: frame ended after " & integer'image(data_cnt_v) &
                 " bytes, expected " & integer'image(GDDRAM_BYTES_C)
            severity warning;
        end if;

        finish;
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
