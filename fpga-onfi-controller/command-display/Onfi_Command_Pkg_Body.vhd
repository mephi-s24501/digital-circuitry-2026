library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

package body Onfi_Command_Pkg is

  type command_name_t is array (onfi_command_t) of string(1 to DISPLAY_COLS_C);

  constant COMMAND_NAME_C : command_name_t :=
  (
    ONFI_READ       => "READ      ",
    ONFI_READ_COPYB => "READ COPYB",
    ONFI_CHGREADCOL => "CHGREADCOL",
    ONFI_RDCACH_RND => "RDCACH RND",
    ONFI_RDCACH_SEQ => "RDCACH SEQ",
    ONFI_RDCACH_END => "RDCACH END",
    ONFI_BLCK_ERASE => "BLCK ERASE",
    ONFI_INTERLV_1  => "INTERLV 1 ",
    ONFI_READSTAT   => "READSTAT  ",
    ONFI_READSTATEN => "READSTATEN",
    ONFI_PAGE_PROGM => "PAGE PROGM",
    ONFI_INTERLV_2  => "INTERLV 2 ",
    ONFI_PGCACHEPGM => "PGCACHEPGM",
    ONFI_COPY_PGM   => "COPY PGM  ",
    ONFI_INTERLV_3  => "INTERLV 3 ",
    ONFI_CHGWRITCOL => "CHGWRITCOL",
    ONFI_READ_ID    => "READ ID   ",
    ONFI_READ_PARAM => "READ PARAM",
    ONFI_READ_UNIQ  => "READ UNIQ ",
    ONFI_GET_FEAT   => "GET FEAT  ",
    ONFI_SET_FEAT   => "SET FEAT  ",
    ONFI_RESET_SYNC => "RESET SYNC",
    ONFI_RESET      => "RESET     "
  );

  -- Font_Memory mapping:
  --   0x00 blank, A..Z 0x01..0x1A, a..z 0x1B..0x34, 0..9 0x35..0x3E.
  function ascii_to_display(c : character) return display_char_t is
    variable code_v : natural;
  begin
    case c is
      when ' ' =>
        return DISPLAY_BLANK_C;
      when 'A' to 'Z' =>
        code_v := character'pos(c) - character'pos('A') + 1;
      when 'a' to 'z' =>
        code_v := character'pos(c) - character'pos('a') + 16#1B#;
      when '0' to '9' =>
        code_v := character'pos(c) - character'pos('0') + 16#35#;
      when others =>
        return DISPLAY_BLANK_C;
    end case;

    return std_logic_vector(to_unsigned(code_v, display_char_t'length));
  end function ascii_to_display;

  function hex_to_display(nibble : std_logic_vector(3 downto 0)) return display_char_t is
  begin
    case nibble is
      when "0000" => return ascii_to_display('0');
      when "0001" => return ascii_to_display('1');
      when "0010" => return ascii_to_display('2');
      when "0011" => return ascii_to_display('3');
      when "0100" => return ascii_to_display('4');
      when "0101" => return ascii_to_display('5');
      when "0110" => return ascii_to_display('6');
      when "0111" => return ascii_to_display('7');
      when "1000" => return ascii_to_display('8');
      when "1001" => return ascii_to_display('9');
      when "1010" => return ascii_to_display('A');
      when "1011" => return ascii_to_display('B');
      when "1100" => return ascii_to_display('C');
      when "1101" => return ascii_to_display('D');
      when "1110" => return ascii_to_display('E');
      when "1111" => return ascii_to_display('F');
      when others => return DISPLAY_BLANK_C;
    end case;
  end function hex_to_display;

  function is_cmd_addressful(cmd : onfi_command_t) return boolean is
  begin
    -- TODO: replace with the real predicate once the address-cycle data is available.
    return true;
  end function is_cmd_addressful;

  function command_row(
    cmd : onfi_command_t
  ) return display_chars_row_t is
    variable name_v : string(1 to DISPLAY_COLS_C);
    variable row    : display_chars_row_t;
  begin
    name_v := COMMAND_NAME_C(cmd);

    for i in name_v'range loop
      row(i - 1) := ascii_to_display(name_v(i));
    end loop;

    return row;
  end function command_row;

  function address_row(
    row_addr : std_logic_vector(15 downto 0);
    col_addr : std_logic_vector(15 downto 0)
  ) return display_chars_row_t is
    variable row : display_chars_row_t;
  begin
    row(0) := DISPLAY_BLANK_C;
    row(1) := hex_to_display(row_addr(15 downto 12));
    row(2) := hex_to_display(row_addr(11 downto 8));
    row(3) := hex_to_display(row_addr(7 downto 4));
    row(4) := hex_to_display(row_addr(3 downto 0));
    row(5) := DISPLAY_BLANK_C;
    row(6) := hex_to_display(col_addr(15 downto 12));
    row(7) := hex_to_display(col_addr(11 downto 8));
    row(8) := hex_to_display(col_addr(7 downto 4));
    row(9) := hex_to_display(col_addr(3 downto 0));
    return row;
  end function address_row;

  function clog2(n : natural) return natural is
  begin
    return natural(ceil(log2(real(n))));
  end function clog2;

end package body Onfi_Command_Pkg;
