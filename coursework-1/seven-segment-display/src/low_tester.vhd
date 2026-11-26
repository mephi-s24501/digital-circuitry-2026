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
  constant clk_cycles_c : natural := 1_600_000;
  constant press_c      : natural := 4;
  constant wait_c       : natural := 10;
  constant blank_c      : natural := 10;

  signal clk_s : std_logic := '0';

  type digit4_t is array (1 to 4) of natural;

  constant blank4_c : digit4_t := (others => blank_c);

  function f_seg_to_digit (s : std_logic_vector(6 downto 0)) return natural is
  begin
    case s is
      when "1000000" => return 0;
      when "1111001" => return 1;
      when "0100100" => return 2;
      when "0110000" => return 3;
      when "0011001" => return 4;
      when "0010010" => return 5;
      when "0000010" => return 6;
      when "1111000" => return 7;
      when "0000000" => return 8;
      when "0010000" => return 9;
      when others    => return blank_c;
    end case;
  end function f_seg_to_digit;

  function f_digit_idx (d : std_logic_vector(3 downto 0)) return natural is
  begin
    for i in 0 to 3 loop
      if d(i) = '1' then
        return i;
      end if;
    end loop;
    return 4;
  end function f_digit_idx;

  function f_expected_digits (val : natural) return digit4_t is
    variable v_v : natural := val;
    variable d_v : digit4_t;
  begin
    if v_v > 9999 then
      v_v := 9999;
    end if;
    d_v(4) := v_v mod 10; v_v := v_v / 10;
    d_v(3) := v_v mod 10; v_v := v_v / 10;
    d_v(2) := v_v mod 10; v_v := v_v / 10;
    d_v(1) := v_v;
    return d_v;
  end function f_expected_digits;

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

  stimulus : process
    variable pass_v    : natural := 0;
    variable fail_v    : natural := 0;
    variable blank4_v  : digit4_t;

    procedure check (cond : boolean; msg : string) is
    begin
      if cond then
        pass_v := pass_v + 1;
      else
        fail_v := fail_v + 1;
        report "LOW FAIL: " & msg severity error;
      end if;
    end procedure check;

    procedure wait_clk (cnt : natural) is
      variable edge_v : natural := 0;
    begin
      while edge_v < cnt loop
        wait until rising_edge(clk_s);
        edge_v := edge_v + 1;
        wait for settle_c;
      end loop;
    end procedure wait_clk;

    procedure do_reset is
    begin
      nRst_o <= '0';
      wait_clk(4);
      nRst_o <= '1';
      wait_clk(4);
    end procedure do_reset;

    procedure press_key is
    begin
      update_o <= '0';
      wait_clk(press_c);
      update_o <= '1';
      wait_clk(wait_c);
    end procedure press_key;

    procedure capture_display (variable digits : out digit4_t) is
      variable tmp_v : digit4_t := (others => blank_c);
    begin
      wait_clk(1);
      for i in 1 to 4 loop
        wait_clk(1);
        case f_digit_idx(digit_i) is
          when 0      => tmp_v(4) := f_seg_to_digit(seg_i);
          when 1      => tmp_v(3) := f_seg_to_digit(seg_i);
          when 2      => tmp_v(2) := f_seg_to_digit(seg_i);
          when 3      => tmp_v(1) := f_seg_to_digit(seg_i);
          when others => null;
        end case;
      end loop;
      digits := tmp_v;
    end procedure capture_display;

    procedure feed_and_check (val : natural) is
      variable frame_v : digit4_t;
    begin
      data_o <= std_logic_vector(to_unsigned(val, 16));
      wait_clk(2);
      press_key;
      capture_display(frame_v);
      check(frame_v = f_expected_digits(val),
            "input=" & integer'image(val));
    end procedure feed_and_check;

  begin
    data_o   <= (others => '0');
    update_o <= '1';

    do_reset;

    data_o <= std_logic_vector(to_unsigned(1234, 16));
    wait_clk(30);
    capture_display(blank4_v);
    check(blank4_v = blank4_c, "display stays blank until the key is pressed");

    for val in 0 to 65535 loop
      feed_and_check(val);
    end loop;

    if fail_v = 0 then
      report "TESTER: all checks passed (" & integer'image(pass_v) & " OK)";
    else
      report "TESTER: FAILED " & integer'image(fail_v) & " of "
             & integer'image(pass_v + fail_v) & " checks" severity error;
    end if;

    wait;
  end process stimulus;
end architecture sim;
