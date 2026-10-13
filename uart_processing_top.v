/*
The PC will send the byte sample to the FPGA RX that follows the UART 8N1 protocol. 
When the RX receives the byte sucessfully, it will write it into the FIFO buffer that is designed to handle stall conditions. 
Then the sample will be input into the moving average calculator when the transmitter has finished transmitting the previous result. 
This design decision is made so that the valid previous result can stay at the transmitter input for clarity. 
This is preferred over the design where the new sample will be calculated immediately following the start of the transmission because needing 1-2 more clock cycles for clarity is a good tradeoff. 
Then the TX will send back the result to the PC that also follows the UART 8N1 protocol.

*/

module uart_processing_top(
	input clock,
	input reset_n,
	input uart_rx,
	
	output uart_tx
);
wire result_valid;
wire [7:0] result;
wire tx_start = result_valid;
wire tx_busy;

wire [7:0] rx_data;
wire rx_valid;

wire write_enable = rx_valid;
wire read_enable = !tx_busy;
wire [7:0] read_data;
wire fifo_full;
wire fifo_empty;

wire safe_read_enable = read_enable & !fifo_empty;

reg data_valid;
always @(posedge clock or negedge reset_n) begin
    if (!reset_n)
        data_valid <= 1'b0;
    else
        data_valid <= safe_read_enable;
end


uart_tx uart_tx_unit(
	.clock(clock),
	.reset_n(reset_n),
	.tx_data(result),
	.tx_start(tx_start), 
	
	.tx(uart_tx),
	.tx_busy(tx_busy)
);


uart_rx uart_rx_unit(
	.clock(clock),
	.reset_n(reset_n),
	.rx(uart_rx),
	
	.rx_data(rx_data),
	.rx_valid(rx_valid)
);

fifo fifo_unit(
	.clock(clock),
	.reset_n(reset_n),
	.write_enable(write_enable) , 
	.read_enable(read_enable) , 
	.write_data(rx_data),
	.read_data(read_data),
	.fifo_full(fifo_full),
	.fifo_empty(fifo_empty)
);

moving_average moving_average_unit(
	.clock(clock),
	.reset_n(reset_n),
	.data(read_data),
	.data_valid(data_valid),  
	.result(result),
	.result_valid(result_valid)
);

endmodule