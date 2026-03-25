# Define the two clocks on their input ports
create_clock -period 10.000 -name W_CLK [get_ports W_CLK]
create_clock -period 17.000 -name R_CLK -waveform {0.000 8.500} [get_ports R_CLK]

# MOST CRITICAL LINE FOR ASYNC FIFO:
# Tell Vivado these two clocks are completely independent.
# Without this, it tries to time paths between them and gives
# thousands of false violations - all meaningless.
set_clock_groups -asynchronous -group [get_clocks R_CLK] -group [get_clocks W_CLK]

# Tell Vivado NOT to time the CDC crossing paths.
# The first FF in each synchronizer is allowed to go metastable -
# that is the whole point. Only the path INTO the first FF is excluded.
set_false_path -from [get_cells -hier -filter {NAME =~ *FIFO_R_Pointer*R_ptr_reg*}] -to [get_cells -hier -filter {NAME =~ *Sync_R2W*Wq1_rptr_reg*}]

set_false_path -from [get_cells -hier -filter {NAME =~ *FIFO_Write_Pointer*W_ptr_reg*}] -to [get_cells -hier -filter {NAME =~ *Sync_W2R*Rq1_wptr_reg*}]

# Resets are asynchronous - do not time them like data paths
set_false_path -from [get_ports W_rst_n]
set_false_path -from [get_ports R_rst_n]

# Input delays - how long before the W_CLK edge does your input arrive
set_input_delay -clock W_CLK -max 2.000 [get_ports {W_inc W_Data}]
set_input_delay -clock W_CLK -min 0.500 [get_ports {W_inc W_Data}]
set_input_delay -clock R_CLK -max 2.000 [get_ports R_inc]
set_input_delay -clock R_CLK -min 0.500 [get_ports R_inc]

# Output delays - how long after the clock edge must outputs be stable
set_output_delay -clock W_CLK -max 2.000 [get_ports Full]
set_output_delay -clock W_CLK -min 0.200 [get_ports Full]
set_output_delay -clock R_CLK -max 2.000 [get_ports {Empty R_Data}]
set_output_delay -clock R_CLK -min 0.200 [get_ports {Empty R_Data}]

