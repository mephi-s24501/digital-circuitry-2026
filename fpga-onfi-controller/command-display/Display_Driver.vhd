library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  use work.Command_Display_Pkg.all;

-- Renders the 10x4 character area of a 128x64 SSD1306 from the rolling framebuffer.
--
-- Every byte of the GDDRAM stream is generated on the fly from the two
-- displayed glyph pages.  The glyphs live in Framebuffer_Memory and are
-- fetched through its read port, one glyph ahead of the byte being sent.
-- Only the displayed page index is latched per transaction.
--
-- Default view is live: framebuf_ptr_i-1 (previous command) on the upper two
-- text rows and framebuf_ptr_i (newest command) on the lower two rows.
--
-- PgUp#/PgDown# browse older/newer framebuffer slots; Draw# returns to the
-- live view and forces a redraw.
entity Display_Driver is
  generic (
    INPUT_CLOCK_HZ_G : positive := 50_000_000;
    I2C_CLOCK_HZ_G   : positive := 300_000;

    -- Reset timings. Probably leave default.
    RESET_LOW_MS_G  : positive := 1;
    RESET_WAIT_MS_G : positive := 100
  );
  port (
    clk_i  : in std_logic;
    rst_ni : in std_logic;

    framebuf_ptr_i  : in std_logic_vector(clog2(DISPLAY_FRAMEBUFFER_LEN_C) - 1 downto 0);
    framebuf_busy_i : in std_logic;

    -- read port of Framebuffer_Memory
    framebuf_addr_o : out std_logic_vector(7 downto 0);
    framebuf_data_i : in  std_logic_vector(FONT_DATA_WIDTH_C - 1 downto 0);

    -- buttons are assumed to be bounce-free
    pgup_ni   : in std_logic;
    pgdown_ni : in std_logic;
    draw_ni   : in std_logic;

    display_rst_no : out std_logic;
    display_cs_no  : out std_logic;
    display_dc_no  : out std_logic;
    display_scl_io : inout std_logic;
    display_sda_io : inout std_logic
  );
end entity Display_Driver;

architecture rtl of Display_Driver is

  -- 8x12 glyphs in 12x16 cells (4 px gaps on both axes).  Four rows fill
  -- the 64 px panel exactly, so every SSD1306 page lies in a single text row.
  constant X_MARGIN_C : natural := 4;
  constant X_GAP_C    : natural := 4;
  constant Y_GAP_C    : natural := 4;
  constant CELL_W_C   : natural := GLYPH_WIDTH_C + X_GAP_C;
  constant CELL_H_C   : natural := GLYPH_HEIGHT_C + Y_GAP_C;

  constant GDDRAM_PAGE_H_C : natural := 8;
  constant GDDRAM_COLS_C   : natural := 128;
  constant GDDRAM_PAGES_C  : natural := 8;
  constant PAGES_PER_ROW_C : natural := CELL_H_C / GDDRAM_PAGE_H_C; -- 2

  constant FB_PTR_W_C : natural := clog2(DISPLAY_FRAMEBUFFER_LEN_C);
  constant DATA_LEN_C : natural := 1 + GDDRAM_PAGES_C * GDDRAM_COLS_C;
  constant TX_IDX_W_C : natural := clog2(DATA_LEN_C);

  constant RESET_LOW_CYCLES_C   : natural := (INPUT_CLOCK_HZ_G / 1000) * RESET_LOW_MS_G;
  constant RESET_WAIT_CYCLES_C  : natural := (INPUT_CLOCK_HZ_G / 1000) * RESET_WAIT_MS_G;
  constant RESET_TOTAL_CYCLES_C : natural := RESET_LOW_CYCLES_C + RESET_WAIT_CYCLES_C;

  constant RESET_CNT_W_C : natural := clog2(RESET_TOTAL_CYCLES_C);

  constant RESET_TOTAL_LAST_C : std_logic_vector(RESET_CNT_W_C - 1 downto 0) := conv_std_logic_vector(RESET_TOTAL_CYCLES_C - 1, RESET_CNT_W_C);

  constant RESET_LOW_LEVEL_C : std_logic_vector(RESET_CNT_W_C - 1 downto 0) := conv_std_logic_vector(RESET_LOW_CYCLES_C, RESET_CNT_W_C);

  type byte_t is array(natural range <>) of std_logic_vector(7 downto 0);

  -- 0x00: control byte, Co=0 / D/C#=0 -> command bytes follow.
  -- The final 21h/22h set the 128-column, 8-page window used by the data
  -- stream; AFh is last so the panel turns on after the window is configured.
  constant INIT_CMDS_C : byte_t :=
  (
    x"00",
    x"AE",
    x"D5",
    x"80",
    x"A8",
    x"3F",
    x"D3",
    x"00",
    x"40",
    x"8D",
    x"14",
    x"20",
    x"00",
    x"A1",
    x"C8",
    x"DA",
    x"12",
    x"81",
    x"CF",
    x"D9",
    x"F1",
    x"DB",
    x"40",
    x"A4",
    x"A6",
    x"21",
    x"00",
    x"7F",
    x"22",
    x"00",
    x"07",
    x"AF"
  );

  type main_state_t is (
    ST_INIT_OLED,
    ST_WAIT
  );

  type tx_kind_t is (TX_KIND_SETUP, TX_KIND_DATA);
  type tx_state_t is (TX_IDLE, TX_ACTIVE, TX_STOP);

  constant BTN_PGUP_C : natural := 2;
  constant BTN_PGDN_C : natural := 1;
  constant BTN_DRAW_C : natural := 0;

  signal main_state_s : main_state_t;
  signal tx_state_s   : tx_state_t;

  signal reset_cnt_s : std_logic_vector(RESET_CNT_W_C - 1 downto 0);

  signal tx_start_s  : std_logic;
  signal tx_kind_s   : tx_kind_t;
  signal tx_len_s    : std_logic_vector(TX_IDX_W_C - 1 downto 0);
  signal tx_idx_s    : std_logic_vector(TX_IDX_W_C - 1 downto 0);
  signal init_done_s : std_logic;

  signal i2c_ena_s     : std_logic;
  signal i2c_data_wr_s : std_logic_vector(7 downto 0);
  signal i2c_idle_s    : std_logic;
  signal i2c_ack_s     : std_logic;
  signal i2c_ack_d_s   : std_logic;
  signal ack_skip_s    : std_logic;

  signal view_ptr_s  : std_logic_vector(FB_PTR_W_C - 1 downto 0);
  signal draw_ptr_s  : std_logic_vector(FB_PTR_W_C - 1 downto 0);
  signal live_s      : std_logic;
  signal dirty_s     : std_logic;
  signal dirty_clr_s : std_logic;
  signal busy_d_s    : std_logic;

  signal glyph_s   : glyph_t;
  signal rd_addr_s : std_logic_vector(7 downto 0);

  -- buttons sync chain
  signal btn_in_s   : std_logic_vector(2 downto 0);
  signal btn_meta_s : std_logic_vector(2 downto 0);
  signal btn_sync_s : std_logic_vector(2 downto 0);
  signal btn_d_s    : std_logic_vector(2 downto 0);

  function prev_page(p : std_logic_vector) return std_logic_vector is
  begin
    if (p = 0) then
      return conv_std_logic_vector(DISPLAY_FRAMEBUFFER_LEN_C - 1, p'length);
    else
      return p - 1;
    end if;
  end function prev_page;

  function next_page(p : std_logic_vector) return std_logic_vector is
  begin
    if (p = DISPLAY_FRAMEBUFFER_LEN_C - 1) then
      return conv_std_logic_vector(0, p'length);
    else
      return p + 1;
    end if;
  end function next_page;

begin

  display_cs_no <= '0'; -- I2C mode: CS# tied low
  display_dc_no <= '0'; -- I2C mode: D/C# is SA0, 0 selects 0111100

  assert CELL_H_C = PAGES_PER_ROW_C * GDDRAM_PAGE_H_C
    report "CELL_H_C must be a multiple of the 8-pixel GDDRAM page height"
    severity failure;

  display_rst_no <= '0' when main_state_s = ST_INIT_OLED and
                             reset_cnt_s < RESET_LOW_LEVEL_C else
                    '1';

  framebuf_addr_o <= rd_addr_s;

  btn_in_s <= pgup_ni & pgdown_ni & draw_ni;

  u_i2c : entity work.i2c_master_flow_mmode(behavior)
    generic map (
      input_clk => INPUT_CLOCK_HZ_G,
      bus_clk   => I2C_CLOCK_HZ_G
    )
    port map (
      addr       => "0111100",
      clk        => clk_i,
      data_wr    => i2c_data_wr_s,
      ena        => i2c_ena_s,
      nRst       => rst_ni,
      rw         => '0',
      busy       => open,
      idle       => i2c_idle_s,
      data_rd    => open,
      scl        => display_scl_io,
      sda        => display_sda_io,
      ack_error  => open,
      data_valid => open,
      ack        => i2c_ack_s,
      mode       => "00"
    );

  -- Power-up reset/init sequencer and transaction starter.
  main_fsm : process (clk_i, rst_ni) is
  begin
    if (rst_ni = '0') then
      main_state_s <= ST_INIT_OLED;
    elsif rising_edge(clk_i) then
      case main_state_s is

        when ST_INIT_OLED =>
          if (reset_cnt_s = RESET_TOTAL_LAST_C) then
            main_state_s <= ST_WAIT;
          end if;

        when ST_WAIT =>
          null;

      end case;
    end if;
  end process main_fsm;

  main_clock : process (clk_i, rst_ni) is
  begin
    if (rst_ni = '0') then
      reset_cnt_s <= (others => '0');
      init_done_s <= '0';
      draw_ptr_s  <= (others => '0');
      tx_start_s  <= '0';
      tx_kind_s   <= TX_KIND_SETUP;
      tx_len_s    <= (others => '0');
      dirty_clr_s <= '0';
    elsif rising_edge(clk_i) then

      if (main_state_s = ST_INIT_OLED and reset_cnt_s = RESET_TOTAL_LAST_C) then
        reset_cnt_s <= (others => '0');
      elsif (main_state_s = ST_INIT_OLED) then
        reset_cnt_s <= reset_cnt_s + 1;
      end if;

      if (main_state_s = ST_WAIT and tx_start_s = '0'
          and tx_state_s = TX_IDLE and init_done_s = '0') then
        init_done_s <= '1';
        tx_kind_s   <= TX_KIND_SETUP;
        tx_len_s    <= conv_std_logic_vector(INIT_CMDS_C'length, TX_IDX_W_C);
      elsif (main_state_s = ST_WAIT and tx_start_s = '0'
             and tx_state_s = TX_IDLE and init_done_s = '1'
             and dirty_s = '1' and framebuf_busy_i = '0') then
        tx_kind_s <= TX_KIND_DATA;
        tx_len_s  <= conv_std_logic_vector(DATA_LEN_C, TX_IDX_W_C);
      end if;

      if (main_state_s = ST_WAIT and tx_start_s = '0' and tx_state_s = TX_IDLE and
          init_done_s = '1' and dirty_s = '1' and framebuf_busy_i = '0') then
        draw_ptr_s <= view_ptr_s;
      end if;

      -- tx_start_s is still high from the previous edge, so this also keeps a
      -- second transaction from starting before the engine has left TX_IDLE.
      tx_start_s <= '0';
      if (main_state_s = ST_WAIT and tx_start_s = '0' and tx_state_s = TX_IDLE and
          (init_done_s = '0' or (dirty_s = '1' and framebuf_busy_i = '0'))) then
        tx_start_s <= '1';
      end if;

      dirty_clr_s <= '0';
      if (main_state_s = ST_WAIT and tx_start_s = '0' and tx_state_s = TX_IDLE and
          init_done_s = '1' and dirty_s = '1' and framebuf_busy_i = '0') then
        dirty_clr_s <= '1';
      end if;
    end if;
  end process main_clock;

  -- I2C transaction state register.
  tx_fsm : process (clk_i, rst_ni) is
  begin
    if (rst_ni = '0') then
      tx_state_s <= TX_IDLE;
    elsif rising_edge(clk_i) then
      case tx_state_s is

        when TX_IDLE =>
          if (tx_start_s = '1') then
            tx_state_s <= TX_ACTIVE;
          end if;

        when TX_ACTIVE =>
          if (i2c_ack_s = '1' and i2c_ack_d_s = '0') then
            if (tx_idx_s = tx_len_s - 1) then
              tx_state_s <= TX_STOP;
            end if;
          end if;

        when TX_STOP =>
          if (i2c_idle_s = '1') then
            tx_state_s <= TX_IDLE;
          end if;

      end case;
    end if;
  end process tx_fsm;

  -- I2C byte-stream engine.  ena is held high for the whole block; the
  -- next data_wr is presented on every ACK rising edge.  The last ACK drops
  -- ena, which makes the master generate STOP.
  tx_clock : process (clk_i, rst_ni) is

    -- One GDDRAM byte: bit b is display row 8*page+b of column col.  Rows
    -- 0..1 of a text row come from the latched page, rows 2..3 from its
    -- predecessor; the glyph for the cell has already been fetched from RAM.
    function data_byte(
      idx   : std_logic_vector(TX_IDX_W_C - 1 downto 0);
      glyph : glyph_t
    ) return std_logic_vector is
      variable page_v : natural;
      variable col_v  : natural;
      variable dx_v   : integer;
      variable gx_v   : natural range 0 to CELL_W_C - 1;
      variable gy_v   : natural range 0 to CELL_H_C - 1;
      variable byte_v : std_logic_vector(7 downto 0) := (others => '0');
    begin
      page_v := conv_integer(idx) / GDDRAM_COLS_C;
      col_v  := conv_integer(idx) mod GDDRAM_COLS_C;
      dx_v   := col_v - X_MARGIN_C;

      if (dx_v >= 0 and dx_v < DISPLAY_COLS_C * CELL_W_C) then
        gx_v := dx_v mod CELL_W_C;

        if (gx_v < GLYPH_WIDTH_C) then
          for b in 0 to 7 loop
            gy_v := (page_v mod PAGES_PER_ROW_C) * GDDRAM_PAGE_H_C + b;
            if (gy_v < GLYPH_HEIGHT_C) then
              byte_v(b) := glyph(gy_v * GLYPH_WIDTH_C +
                                 GLYPH_WIDTH_C - 1 - gx_v);
            end if;
          end loop;
        end if;
      end if;

      return byte_v;
    end function data_byte;

    -- RAM address of the glyph that owns byte idx.  The selected page fills
    -- the lower two text rows and its predecessor the upper two, so older
    -- commands scroll in at the top.  Bytes that fall outside the text area
    -- map to address 0 and are discarded by data_byte.
    function glyph_addr(
      idx  : std_logic_vector(TX_IDX_W_C - 1 downto 0);
      fb_view : std_logic_vector(FB_PTR_W_C - 1 downto 0)
    ) return std_logic_vector is
      variable page_v : natural;
      variable col_v  : natural;
      variable dx_v   : integer;
      variable ch_v   : natural range 0 to DISPLAY_COLS_C - 1;
      variable gx_v   : natural range 0 to CELL_W_C - 1;
      variable row_v  : natural range 0 to GDDRAM_PAGES_C / PAGES_PER_ROW_C - 1;
      variable sel_v  : std_logic_vector(FB_PTR_W_C - 1 downto 0);
      variable addr_v : natural := 0;
    begin
      page_v := conv_integer(idx) / GDDRAM_COLS_C;
      col_v  := conv_integer(idx) mod GDDRAM_COLS_C;
      dx_v   := col_v - X_MARGIN_C;

      if (dx_v >= 0 and dx_v < DISPLAY_COLS_C * CELL_W_C) then
        ch_v := dx_v / CELL_W_C;
        gx_v := dx_v mod CELL_W_C;

        if (gx_v < GLYPH_WIDTH_C) then
          row_v := page_v / PAGES_PER_ROW_C;
          if (row_v < DISPLAY_ROWS_C) then
            sel_v := prev_page(fb_view);
          else
            sel_v := fb_view;
          end if;

          addr_v := conv_integer(sel_v) * DISPLAY_PAGE_LEN_C +
                    (row_v mod 2) * DISPLAY_COLS_C + ch_v;
        end if;
      end if;

      return conv_std_logic_vector(addr_v, 8);
    end function glyph_addr;

    function tx_byte(
      kind  : tx_kind_t;
      idx   : std_logic_vector(TX_IDX_W_C - 1 downto 0);
      glyph : glyph_t
    ) return std_logic_vector is
      variable i : natural;
    begin
      if (kind = TX_KIND_SETUP) then
        i := conv_integer(idx);
        if (i < INIT_CMDS_C'length) then
          return INIT_CMDS_C(i);
        else
          return x"00";
        end if;
      elsif (idx = 0) then
        return x"40"; -- data control byte
      else
        return data_byte(idx - 1, glyph);
      end if;
    end function tx_byte;

  begin
    if (rst_ni = '0') then
      tx_idx_s      <= (others => '0');
      i2c_ena_s     <= '0';
      i2c_data_wr_s <= (others => '0');
      i2c_ack_d_s   <= '0';
      ack_skip_s    <= '0';
      glyph_s       <= (others => '0');
      rd_addr_s     <= (others => '0');
    elsif rising_edge(clk_i) then
      i2c_ack_d_s <= i2c_ack_s;
      glyph_s     <= framebuf_data_i(GLYPH_BITS_C - 1 downto 0);

      -- The first ACK of a transaction acknowledges the slave address, not
      -- a payload byte.  Skipping it keeps the byte counter aligned with
      -- tx_len_s, so the final payload byte is not dropped.
      if (tx_state_s = TX_IDLE and tx_start_s = '1') then
        ack_skip_s <= '1';
      elsif (tx_state_s = TX_ACTIVE and i2c_ack_s = '1' and i2c_ack_d_s = '0') then
        ack_skip_s <= '0';
      end if;

      if (tx_state_s = TX_IDLE and tx_start_s = '1') then
        tx_idx_s <= (others => '0');
      elsif (tx_state_s = TX_ACTIVE and i2c_ack_s = '1' and i2c_ack_d_s = '0' and
             ack_skip_s = '0' and tx_idx_s /= tx_len_s - 1) then
        tx_idx_s <= tx_idx_s + 1;
      end if;

      if (tx_state_s = TX_IDLE and tx_start_s = '1') then
        i2c_ena_s <= '1';
      elsif (tx_state_s = TX_ACTIVE and i2c_ack_s = '1' and i2c_ack_d_s = '0' and
             ack_skip_s = '0' and tx_idx_s = tx_len_s - 1) then
        i2c_ena_s <= '0';
      end if;

      if (tx_state_s = TX_IDLE and tx_start_s = '1') then
        i2c_data_wr_s <= tx_byte(tx_kind_s,
                                 conv_std_logic_vector(0, TX_IDX_W_C),
                                 glyph_s);
      elsif (tx_state_s = TX_ACTIVE and i2c_ack_s = '1' and i2c_ack_d_s = '0' and
             ack_skip_s = '0' and tx_idx_s /= tx_len_s - 1) then
        i2c_data_wr_s <= tx_byte(tx_kind_s, tx_idx_s + 1, glyph_s);
      end if;

      -- Fetch the glyph for the byte after the one just presented; the RAM
      -- latency is far shorter than the ACK interval.  The first data glyph
      -- is fetched while the control byte goes out.
      if (tx_state_s = TX_IDLE and tx_start_s = '1' and
          tx_kind_s = TX_KIND_DATA) then
        rd_addr_s <= glyph_addr(conv_std_logic_vector(0, TX_IDX_W_C),
                                draw_ptr_s);
      elsif (tx_state_s = TX_ACTIVE and i2c_ack_s = '1' and i2c_ack_d_s = '0' and
             ack_skip_s = '0' and tx_idx_s /= tx_len_s - 1 and
             tx_kind_s = TX_KIND_DATA and tx_idx_s + 1 < DATA_LEN_C - 1) then
        rd_addr_s <= glyph_addr(tx_idx_s + 1, draw_ptr_s);
      end if;
    end if;
  end process tx_clock;

  -- View selection and redraw request.
  control : process (clk_i, rst_ni) is
  begin
    if (rst_ni = '0') then
      view_ptr_s <= conv_std_logic_vector(DISPLAY_FRAMEBUFFER_LEN_C - 1, FB_PTR_W_C);
      live_s     <= '1';
      dirty_s    <= '1';
      busy_d_s   <= '0';

      btn_meta_s <= (others => '1');
      btn_sync_s <= (others => '1');
      btn_d_s    <= (others => '1');
    elsif rising_edge(clk_i) then
      busy_d_s <= framebuf_busy_i;

      btn_meta_s <= btn_in_s;
      btn_sync_s <= btn_meta_s;
      btn_d_s    <= btn_sync_s;

      if (btn_sync_s(BTN_PGUP_C) = '0' and btn_d_s(BTN_PGUP_C) = '1') then
        view_ptr_s <= prev_page(view_ptr_s);
      elsif (btn_sync_s(BTN_PGDN_C) = '0' and btn_d_s(BTN_PGDN_C) = '1' and
             view_ptr_s /= framebuf_ptr_i) then
        view_ptr_s <= next_page(view_ptr_s);
      elsif (btn_sync_s(BTN_DRAW_C) = '0' and btn_d_s(BTN_DRAW_C) = '1') then
        view_ptr_s <= framebuf_ptr_i;
      elsif (framebuf_busy_i = '0' and busy_d_s = '1' and live_s = '1') then
        view_ptr_s <= framebuf_ptr_i;
      end if;

      if (btn_sync_s(BTN_PGUP_C) = '0' and btn_d_s(BTN_PGUP_C) = '1') then
        live_s <= '0';
      elsif (btn_sync_s(BTN_PGDN_C) = '0' and btn_d_s(BTN_PGDN_C) = '1') and
            view_ptr_s /= framebuf_ptr_i then
        if (next_page(view_ptr_s) = framebuf_ptr_i) then
          live_s <= '1';
        end if;
      elsif (btn_sync_s(BTN_DRAW_C) = '0' and btn_d_s(BTN_DRAW_C) = '1') then
        live_s <= '1';
      end if;

      -- Button and page-complete events win over a clear request from the
      -- main process in the same clock, so a new view is not lost.
      if (btn_sync_s(BTN_PGUP_C) = '0' and btn_d_s(BTN_PGUP_C) = '1') or
         (btn_sync_s(BTN_PGDN_C) = '0' and btn_d_s(BTN_PGDN_C) = '1' and
          view_ptr_s /= framebuf_ptr_i) or
         (btn_sync_s(BTN_DRAW_C) = '0' and btn_d_s(BTN_DRAW_C) = '1') or
         (framebuf_busy_i = '0' and busy_d_s = '1' and live_s = '1') then
        dirty_s <= '1';
      elsif (dirty_clr_s = '1') then
        dirty_s <= '0';
      end if;
    end if;
  end process control;

end architecture rtl;
