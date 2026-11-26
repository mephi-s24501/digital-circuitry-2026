library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  use work.Command_Display_Pkg.all;

-- Builds a 2x10 glyph page from an ONFI command and stores it in the
-- Framebuffer_Memory RAM (256 x 108, the glyph lives in the low 96 bits).
-- The module owns the RAM: it drives the write port and exposes the read
-- port so that Display_Driver can fetch glyphs by address.
--
-- RAM word address is page * DISPLAY_PAGE_LEN_C + glyph index, so the ten
-- pages occupy addresses 0..199 of the 256-word memory.
entity Framebuffer is
  port (
    clk_i  : in  std_logic;
    rst_ni : in  std_logic;

    load_i : in  std_logic;
    cmd_i  : in  onfi_command_t;
    row_i  : in  std_logic_vector(15 downto 0);
    col_i  : in  std_logic_vector(15 downto 0);

    -- read port of the shared framebuffer RAM
    framebuf_addr_i : in  std_logic_vector(7 downto 0);
    framebuf_data_o : out std_logic_vector(FONT_DATA_WIDTH_C - 1 downto 0);

    framebuf_ptr_o : out std_logic_vector(clog2(DISPLAY_FRAMEBUFFER_LEN_C) - 1 downto 0);
    busy_o         : out std_logic
  );
end entity Framebuffer;

architecture rtl of Framebuffer is

  type fsm_t is (IDLE, MEM_FETCH, MEM_WAIT, MEM_CAPTURE);

  signal state_s        : fsm_t;
  signal framebuf_ptr_s : std_logic_vector(clog2(DISPLAY_FRAMEBUFFER_LEN_C) - 1 downto 0);
  signal char_idx_s     : std_logic_vector(clog2(DISPLAY_PAGE_LEN_C) - 1 downto 0);
  signal page_s         : display_chars_t(0 to DISPLAY_PAGE_LEN_C - 1);
  signal font_addr_s    : std_logic_vector(FONT_ADDR_WIDTH_C - 1 downto 0);
  signal font_data_s    : std_logic_vector(FONT_DATA_WIDTH_C - 1 downto 0);
  signal font_glyph_s   : glyph_t;

  signal framebuf_addr_s : std_logic_vector(7 downto 0);
  signal framebuf_data_s : std_logic_vector(FONT_DATA_WIDTH_C - 1 downto 0);
  signal framebuf_wren_s : std_logic;

begin

  assert GLYPH_BITS_C <= FONT_DATA_WIDTH_C
    report "Glyph size exceeds Font_Memory output width"
    severity failure;

  assert DISPLAY_FRAMEBUFFER_LEN_C * DISPLAY_PAGE_LEN_C <= 256
    report "Framebuffer does not fit into Framebuffer_Memory"
    severity failure;

  font_glyph_s <= font_data_s(GLYPH_BITS_C - 1 downto 0);

  framebuf_ptr_o <= framebuf_ptr_s;
  busy_o         <= '1' when state_s /= IDLE else
                    '0';

  -- One RAM word per glyph: page * 20 + index inside the page.
  framebuf_addr_s <= conv_std_logic_vector(conv_integer(framebuf_ptr_s) * DISPLAY_PAGE_LEN_C + conv_integer(char_idx_s), 8);

  framebuf_data_s <= conv_std_logic_vector(0, FONT_DATA_WIDTH_C - GLYPH_BITS_C) & font_glyph_s;

  -- The RAM write port is clocked with the same clock as the ROM.  The ROM
  -- needs two clocks (address register plus output register) to present the
  -- addressed glyph, so the write happens in the MEM_CAPTURE cycle after
  -- MEM_FETCH and MEM_WAIT have given it that time.
  framebuf_wren_s <= '1' when state_s = MEM_CAPTURE else
                     '0';

  u_framebuffer_memory : entity work.Framebuffer_Memory
    port map (
      clock     => clk_i,
      data      => framebuf_data_s,
      rdaddress => framebuf_addr_i,
      wraddress => framebuf_addr_s,
      wren      => framebuf_wren_s,
      q         => framebuf_data_o
    );

  u_font_memory : entity work.Font_Memory
    port map (
      address => font_addr_s,
      clock   => clk_i,
      q       => font_data_s
    );

  fsm : process (clk_i, rst_ni) is
  begin
    if (rst_ni = '0') then
      state_s <= IDLE;
    elsif rising_edge(clk_i) then
      case state_s is
        when IDLE =>
          if (load_i = '1') then
            state_s <= MEM_FETCH;
          end if;

        when MEM_FETCH =>
          state_s <= MEM_WAIT;

        when MEM_WAIT =>
          -- the registered ROM output is only valid after two clocks
          state_s <= MEM_CAPTURE;

        when MEM_CAPTURE =>
          if (char_idx_s = DISPLAY_PAGE_LEN_C - 1) then
            state_s <= IDLE;
          else
            state_s <= MEM_FETCH;
          end if;
      end case;
    end if;
  end process fsm;

  clock : process (clk_i, rst_ni) is
    variable page_v : display_chars_t(0 to DISPLAY_PAGE_LEN_C - 1);
  begin
    if (rst_ni = '0') then
      framebuf_ptr_s <= conv_std_logic_vector(DISPLAY_FRAMEBUFFER_LEN_C - 1,
                                              clog2(DISPLAY_FRAMEBUFFER_LEN_C));
      char_idx_s     <= (others => '0');
      page_s         <= (others => DISPLAY_BLANK_C);
      font_addr_s    <= (others => '0');
    elsif rising_edge(clk_i) then
      if (state_s = IDLE and load_i = '1') then
        page_v(0 to DISPLAY_COLS_C - 1) := command_row(cmd_i);
        if is_cmd_addressful(cmd_i) then
          page_v(DISPLAY_COLS_C to DISPLAY_PAGE_LEN_C - 1) := address_row(row_i, col_i);
        else
          page_v(DISPLAY_COLS_C to DISPLAY_PAGE_LEN_C - 1) := DISPLAY_BLANK_ROW_C;
        end if;

        page_s      <= page_v;
        font_addr_s <= page_v(0);
        char_idx_s  <= (others => '0');

        -- the new command goes into the next slot, which becomes current
        if (framebuf_ptr_s = DISPLAY_FRAMEBUFFER_LEN_C - 1) then
          framebuf_ptr_s <= (others => '0');
        else
          framebuf_ptr_s <= framebuf_ptr_s + 1;
        end if;
      elsif (state_s = MEM_CAPTURE) then
        -- glyph char_idx_s is written by the RAM write port in this cycle
        if (char_idx_s /= DISPLAY_PAGE_LEN_C - 1) then
          char_idx_s  <= char_idx_s + 1;
          font_addr_s <= page_s(conv_integer(char_idx_s) + 1);
        end if;
      end if;
    end if;
  end process clock;

end architecture rtl;
