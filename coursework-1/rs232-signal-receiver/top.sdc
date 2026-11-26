# Clocks
create_clock -name clk_50 -period 20.000 [get_ports {clki_i}]
derive_pll_clocks
derive_clock_uncertainty

# Asynchronous pins
set_false_path -from [get_ports {rst_ni}]
set_false_path -from [get_ports {data_i}]

# Nothing is driving these synchronously in my case
# They go to gpio outputs
set_false_path -to [get_ports {data_out_o[*] err_o out_en_o}]

# PLL output
create_generated_clock -name clk0_o                                        \
    -source [get_pins {u_pll|altpll_component|auto_generated|pll1|clk[0]}] \
    [get_ports {clk0_o}]
