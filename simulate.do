# Usage: do simulate.do fifo fifo_tb

set design $1
set testbench $2

quit -sim
vlib work
vlog "${design}.v" "${testbench}.v"
vsim -voptargs=+acc "work.${testbench}"
add wave -r "sim:/${testbench}/*"
run -all