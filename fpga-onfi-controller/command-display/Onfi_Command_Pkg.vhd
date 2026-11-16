library ieee;
  use ieee.std_logic_1164.all;

package Onfi_Command_Pkg is

  -- ceil(log2(n))
  function clog2(n : natural) return natural;

  type onfi_command_t is (
    ONFI_READ,
    ONFI_READ_COPYB,
    ONFI_CHGREADCOL,
    ONFI_RDCACH_RND,
    ONFI_RDCACH_SEQ,
    ONFI_RDCACH_END,
    ONFI_BLCK_ERASE,
    ONFI_INTERLV_1,
    ONFI_READSTAT,
    ONFI_READSTATEN,
    ONFI_PAGE_PROGM,
    ONFI_INTERLV_2,
    ONFI_PGCACHEPGM,
    ONFI_COPY_PGM,
    ONFI_INTERLV_3,
    ONFI_CHGWRITCOL,
    ONFI_READ_ID,
    ONFI_READ_PARAM,
    ONFI_READ_UNIQ,
    ONFI_GET_FEAT,
    ONFI_SET_FEAT,
    ONFI_RESET_SYNC,
    ONFI_RESET
  );

  constant DISPLAY_COLS_C     : positive := 10;
  constant DISPLAY_ROWS_C     : positive := 2;
  constant DISPLAY_PAGE_LEN_C : positive := DISPLAY_COLS_C * DISPLAY_ROWS_C;

  subtype display_char_t is std_logic_vector(5 downto 0);
  type    display_chars_t is array (natural range <>) of display_char_t;
  subtype display_chars_row_t is display_chars_t(0 to DISPLAY_COLS_C - 1);

  constant DISPLAY_BLANK_C     : display_char_t                           := (others => '0');
  constant DISPLAY_BLANK_ROW_C : display_chars_t(0 to DISPLAY_COLS_C - 1) := (others => DISPLAY_BLANK_C);

  constant GLYPH_WIDTH_C  : positive := 8;
  constant GLYPH_HEIGHT_C : positive := 12;
  constant GLYPH_BITS_C   : positive := GLYPH_WIDTH_C * GLYPH_HEIGHT_C;

  constant FONT_ADDR_WIDTH_C : positive := 6;
  constant FONT_DATA_WIDTH_C : positive := 108;

  subtype glyph_t is std_logic_vector(GLYPH_BITS_C - 1 downto 0);
  type    glyphs_t is array (natural range <>) of glyph_t;

  subtype display_page_t is glyphs_t(0 to DISPLAY_PAGE_LEN_C - 1);
  type    display_framebuffer_t is array (natural range <>) of display_page_t;

  constant DISPLAY_FRAMEBUFFER_LEN_C : natural := 10;

  constant GLYPH_BLANK_C : glyph_t := (others => '0');

  function is_cmd_addressful(cmd : onfi_command_t) return boolean;
  function command_row(cmd : onfi_command_t) return display_chars_row_t;
  function address_row(
    row_addr : in std_logic_vector(15 downto 0);
    col_addr : in std_logic_vector(15 downto 0)
  ) return display_chars_row_t;

end package Onfi_Command_Pkg;
