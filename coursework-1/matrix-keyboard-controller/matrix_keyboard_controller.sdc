# 50 MHz system clock
create_clock -name clk_i -period 20.000 [get_ports {clk_i}]
derive_clock_uncertainty

# Asynchronous inputs
set_false_path -from [get_ports {nRst_i}]
set_false_path -from [get_ports {rows_i[*]}]

# Outputs without an external synchronous capture
set_false_path -to [get_ports {columns_o[*]}]
set_false_path -to [get_ports {n_key_code_o[*]}]