library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity low_tester is
  port (
    data_o   : out std_logic_vector(15 downto 0) := (others => '0');
    update_o : out std_logic := '0';
    nRst_o   : out std_logic := '1';
    clk_o    : out std_logic := '0';

    seg_i    : in  std_logic_vector(6 downto 0);
    digit_i  : in  std_logic_vector(3 downto 0)
  );
end entity low_tester;

architecture sim of low_tester is
  constant clk_period_c : time    := 20 ns;
  constant settle_c     : time    := 1 ns;
  constant clk_cycles_c : natural := 4096;
  constant mem_press_c  : natural := 4;
  constant dut_wait_c   : natural := 10;

  signal clk_s        : std_logic := '0';
  signal mem_clk_s    : std_logic := '0';
  signal mem_update_s : std_logic := '1';
  signal nRst_s       : std_logic := '1';

  signal conv_data_s : std_logic_vector(15 downto 0) := (others => '0');
  signal conv_bcd_s  : std_logic_vector(15 downto 0);

  signal dec_bcd_s : std_logic_vector(3 downto 0) := (others => '0');
  signal dec_seg_s : std_logic_vector(6 downto 0);

  signal mem_in_s  : std_logic_vector(27 downto 0) := (others => '0');
  signal mem_out_s : std_logic_vector(27 downto 0);

  signal mux_in_s    : std_logic_vector(27 downto 0) := (others => '0');
  signal mux_seg_s   : std_logic_vector(6 downto 0);
  signal mux_digit_s : std_logic_vector(3 downto 0);

  type char4_t is array (1 to 4) of character;

  type seg_table_t is array (natural range 0 to 9) of std_logic_vector(6 downto 0);
  constant seg_table_c : seg_table_t := (
    0 => "1000000", 1 => "1111001", 2 => "0100100", 3 => "0110000",
    4 => "0011001", 5 => "0010010", 6 => "0000010", 7 => "1111000",
    8 => "0000000", 9 => "0010000"
  );

  constant seg_blank_c   : std_logic_vector(6 downto 0)   := "1111111";
  constant seg_all_on_c  : std_logic_vector(27 downto 0) := (others => '0');
  constant seg_all_off_c : std_logic_vector(27 downto 0) := (others => '1');

  constant digit_active_c : std_logic := '1';

  function f_seg_to_char (s : std_logic_vector(6 downto 0)) return character is
  begin
    case s is
      when "1000000" => return '0';
      when "1111001" => return '1';
      when "0100100" => return '2';
      when "0110000" => return '3';
      when "0011001" => return '4';
      when "0010010" => return '5';
      when "0000010" => return '6';
      when "1111000" => return '7';
      when "0000000" => return '8';
      when "0010000" => return '9';
      when others    => return 'X';
    end case;
  end function f_seg_to_char;

  function f_bin_str (vec : std_logic_vector) return string is
    variable res_v : string(1 to vec'length);
  begin
    for i in vec'high downto vec'low loop
      case vec(i) is
        when '1'    => res_v(vec'high - i + 1) := '1';
        when '0'    => res_v(vec'high - i + 1) := '0';
        when others => res_v(vec'high - i + 1) := 'X';
      end case;
    end loop;
    return res_v;
  end function f_bin_str;

  function f_expected_bcd (val : natural) return std_logic_vector is
    variable v_v                    : natural := val;
    variable d0_v, d1_v, d2_v, d3_v : natural;
  begin
    if v_v > 9999 then
      return "1001100110011001";
    end if;
    d0_v := v_v mod 10;  v_v := v_v / 10;
    d1_v := v_v mod 10;  v_v := v_v / 10;
    d2_v := v_v mod 10;  v_v := v_v / 10;
    d3_v := v_v;
    return std_logic_vector(to_unsigned(d3_v, 4)) &
           std_logic_vector(to_unsigned(d2_v, 4)) &
           std_logic_vector(to_unsigned(d1_v, 4)) &
           std_logic_vector(to_unsigned(d0_v, 4));
  end function f_expected_bcd;

  function f_digit_pick (idx : natural) return std_logic_vector is
    variable res_v : std_logic_vector(3 downto 0) := (others => not digit_active_c);
  begin
    res_v(idx) := digit_active_c;
    return res_v;
  end function f_digit_pick;

  function f_digit_idx (d : std_logic_vector(3 downto 0)) return natural is
  begin
    for i in 0 to 3 loop
      if d = f_digit_pick(i) then
        return i;
      end if;
    end loop;
    return 4;
  end function f_digit_idx;

begin

  clk_gen : process
  begin
    for i in 1 to clk_cycles_c loop
      clk_s <= '0';
      wait for clk_period_c / 2;
      clk_s <= '1';
      wait for clk_period_c / 2;
    end loop;
    clk_s <= '0';
    wait;
  end process clk_gen;

  clk_o <= clk_s;

  u_mem : entity work.dut_segment_memory
    port map (
      segments_i => mem_in_s,
      update_li  => mem_update_s,
      clk_i      => clk_s,
      nRst_li    => nRst_s,
      segments_o => mem_out_s
    );

  u_mux : entity work.dut_display_mux
    generic map (
      scan_div_c => 4
    )
    port map (
      segments_i => mux_in_s,
      clk_i      => clk_s,
      nRst_li    => nRst_s,
      seg_o      => mux_seg_s,
      digit_o    => mux_digit_s
    );

  u_conv : entity work.dut_bin_to_bcd
    port map (
      data_i => conv_data_s,
      bcd_o  => conv_bcd_s
    );

  u_dec : entity work.dut_seven_seg
    port map (
      bcd_i => dec_bcd_s,
      seg_o => dec_seg_s
    );

  stimulus : process
    variable pass_v : natural := 0;
    variable fail_v : natural := 0;

    procedure check (cond : boolean; msg : string) is
    begin
      if cond then
        pass_v := pass_v + 1;
        report "LOW  OK: " & msg;
      else
        fail_v := fail_v + 1;
        report "LOW FAIL: " & msg severity error;
      end if;
    end procedure check;

    procedure wait_clk_scan (cnt : natural) is
      variable edge_v : natural := 0;
    begin
      while edge_v < cnt loop
        wait until rising_edge(clk_s);
        edge_v := edge_v + 1;
        wait for settle_c;
      end loop;
    end procedure wait_clk_scan;

    procedure wait_clk_mem (cnt : natural) is
      variable edge_v : natural := 0;
    begin
      while edge_v < cnt loop
        wait until rising_edge(mem_clk_s);
        edge_v := edge_v + 1;
        wait for settle_c;
      end loop;
    end procedure wait_clk_mem;

    procedure do_reset is
    begin
      nRst_s <= '0';
      nRst_o <= '0';
      wait_clk_scan(4);
      nRst_s <= '1';
      nRst_o <= '1';
      wait_clk_scan(4);
    end procedure do_reset;

    procedure press_mem_key is
    begin
      mem_update_s <= '0';
      wait_clk_scan(mem_press_c);
      mem_update_s <= '1';
      wait_clk_scan(dut_wait_c);
    end procedure press_mem_key;

    procedure press_dut_key is
    begin
      update_o <= '0';
      wait_clk_scan(mem_press_c);
      update_o <= '1';
      wait_clk_scan(dut_wait_c);
    end procedure press_dut_key;

    procedure check_conv (val : natural) is
    begin
      conv_data_s <= std_logic_vector(to_unsigned(val, 16));
      wait_clk_scan(1);
      check(conv_bcd_s = f_expected_bcd(val),
            "bin_to_bcd(" & integer'image(val) & ") -> " & f_bin_str(conv_bcd_s)
            & " expected " & f_bin_str(f_expected_bcd(val)));
    end procedure check_conv;

    procedure capture_display (variable chars : out char4_t) is
      variable tmp_v : char4_t := (others => ' ');
    begin
      wait_clk_scan(1);
      for i in 1 to 4 loop
        wait_clk_scan(1);
        case f_digit_idx(digit_i) is
          when 0      => tmp_v(4) := f_seg_to_char(seg_i);
          when 1      => tmp_v(3) := f_seg_to_char(seg_i);
          when 2      => tmp_v(2) := f_seg_to_char(seg_i);
          when 3      => tmp_v(1) := f_seg_to_char(seg_i);
          when others => null;
        end case;
      end loop;
      chars := tmp_v;
    end procedure capture_display;

    procedure check_display (expected : string; msg : string) is
      variable frame_v : char4_t;
      variable got_v   : string(1 to 4);
    begin
      capture_display(frame_v);
      got_v := frame_v(1) & frame_v(2) & frame_v(3) & frame_v(4);
      check(got_v = expected,
            msg & ": expected " & expected & ", got " & got_v);
    end procedure check_display;

    procedure feed_and_check (val : natural; expected : string) is
    begin
      data_o <= std_logic_vector(to_unsigned(val, 16));
      wait_clk_scan(2);
      press_dut_key;
      check_display(expected, "input=" & integer'image(val));
    end procedure feed_and_check;

  begin
    data_o   <= (others => '0');
    update_o <= '1';

    do_reset;
    check(mem_out_s = seg_all_off_c,
          "segment_memory: all segments blank after reset");

    nRst_s <= '0';
    nRst_o <= '0';
    wait for 2 ns;
    check(mux_digit_s = f_digit_pick(0) and mux_seg_s = mux_in_s(6 downto 0),
          "display_mux: digit 0 (units) selected after reset");
    nRst_s <= '1';
    nRst_o <= '1';
    wait_clk_scan(2);

    check_conv(0);
    check_conv(1);
    check_conv(12);
    check_conv(1234);
    check_conv(2710);
    check_conv(9876);
    check_conv(9999);
    check_conv(10000);
    check_conv(65535);

    for d in 0 to 9 loop
      dec_bcd_s <= std_logic_vector(to_unsigned(d, 4));
      wait for 2 ns;
      check(dec_seg_s = seg_table_c(d),
            "seven_seg(" & integer'image(d) & ") -> " & f_bin_str(dec_seg_s));
    end loop;

    for d in 10 to 15 loop
      dec_bcd_s <= std_logic_vector(to_unsigned(d, 4));
      wait for 2 ns;
      check(dec_seg_s = seg_blank_c,
            "seven_seg(" & integer'image(d) & ") -> overflow, all segments blank");
    end loop;

    mem_in_s <= seg_all_on_c;
    wait for 2 ns;
    check(mem_out_s = seg_all_off_c,
          "segment_memory: blank before key press");

    press_mem_key;
    check(mem_out_s = seg_all_on_c,
          "segment_memory: all segments stored after key press");

    mem_in_s <= X"AAAAAA0";
    wait_clk_scan(2);
    check(mem_out_s = seg_all_on_c,
          "segment_memory: old value held while key is not pressed");

    press_mem_key;
    check(mem_out_s = X"AAAAAA0",
          "segment_memory: next key press stores new data");

    nRst_s <= '0';
    wait for 2 ns;
    check(mem_out_s = seg_all_off_c,
          "segment_memory: async reset clears state without a clock edge");
    nRst_s <= '1';
    wait_clk_scan(2);

    mux_in_s <= "1111000" & "0010010" & "0110000" & "1111001";
    wait for 2 ns;

    nRst_s <= '0';
    wait for 2 ns;
    check(mux_digit_s = f_digit_pick(0) and mux_seg_s = mux_in_s(6 downto 0),
          "display_mux: count 0 -> units digit, seg=7");
    nRst_s <= '1';

    wait_clk_scan(4);
    check(mux_digit_s = f_digit_pick(1) and mux_seg_s = mux_in_s(13 downto 7),
          "display_mux: count 1 -> tens digit, seg=5");

    wait_clk_scan(4);
    check(mux_digit_s = f_digit_pick(2) and mux_seg_s = mux_in_s(20 downto 14),
          "display_mux: count 2 -> hundreds digit, seg=3");

    wait_clk_scan(4);
    check(mux_digit_s = f_digit_pick(3) and mux_seg_s = mux_in_s(27 downto 21),
          "display_mux: count 3 -> thousands digit, seg=1");

    wait_clk_scan(4);
    check(mux_digit_s = f_digit_pick(0) and mux_seg_s = mux_in_s(6 downto 0),
          "display_mux: count wraps 3 -> 0");

    nRst_s <= '0';
    wait for 2 ns;
    check(mux_digit_s = f_digit_pick(0),
          "display_mux: async reset stops the counter at digit 0");
    nRst_s <= '1';
    wait_clk_scan(2);

    do_reset;

    data_o <= std_logic_vector(to_unsigned(1234, 16));
    wait_clk_scan(30);
    check_display("XXXX", "display stays blank until the key is pressed");

    feed_and_check(0,     "0000");
    feed_and_check(1,     "0001");
    feed_and_check(12,    "0012");
    feed_and_check(1234,  "1234");
    feed_and_check(2710,  "2710");
    feed_and_check(9876,  "9876");
    feed_and_check(9999,  "9999");
    feed_and_check(10000, "9999");
    feed_and_check(65535, "9999");

    if fail_v = 0 then
      report "TESTER: all checks passed (" & integer'image(pass_v) & " OK)";
    else
      report "TESTER: FAILED " & integer'image(fail_v) & " of "
             & integer'image(pass_v + fail_v) & " checks" severity error;
    end if;

    wait;
  end process stimulus;
end architecture sim;
