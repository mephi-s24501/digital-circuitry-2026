create_clock -name clk -period 20 [get_ports {clk}]
derive_clock_uncertainty

set_input_delay  -clock clk 0 [get_ports {data_i[*]}]
set_output_delay -clock clk 0 [get_ports {quantity_o[*]}]
set_output_delay -clock clk 0 [get_ports {done_o}]

set_false_path -from [get_ports {nRst}]