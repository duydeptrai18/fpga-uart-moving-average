/*
TEST CASES:
1. Initial reset:
   - Verify RX data, FIFO read output, and moving-average result
     are zero after reset.
   - Check that UART TX is HIGH (idle).

2. Zero-filled startup:
   - Send 4, 12, and 8.
   - Verify RX and FIFO data match each transmitted byte.
   - Verify moving-average results of 1, 4, and 6.

3. Oldest-sample replacement:
   - Send 6, replacing the oldest sample (4).
   - Verify the average is (12 + 8 + 2 + 6) / 4 = 7.

4. Reset after processing:
   - Reset the system, then release reset.
   - Send 4 and verify the result is 1, confirming that the
     moving-average history was cleared.

For each sample:
   - Send UART sample concurrently with internal checks.
   - Check RX data, FIFO read data, and processing result.
   - Check the outgoing UART start bit, eight data bits
     (LSB first), and stop bit at their midpoints.
   - Wait for TX completion before sending the next sample.

Failed data/frame checks increment the error counter.
The total error count is printed at the end of simulation.
*/
`timescale 1ns/1ps
module uart_processing_top_tb;
	reg clock;
	reg reset_n;
	reg uart_rx;
	
	wire uart_tx;
	wire rx_valid = uart_processing_top_dut.rx_valid;
	wire [7:0] rx_data = uart_processing_top_dut.rx_data;
	wire data_valid = uart_processing_top_dut.data_valid;
	wire [7:0] read_data = uart_processing_top_dut.read_data;
	wire result_valid = uart_processing_top_dut.result_valid;
	wire [7:0] result = uart_processing_top_dut.result;
	wire tx_busy = uart_processing_top_dut.tx_busy;
	integer k;
	integer errors;
	
uart_processing_top uart_processing_top_dut(
	.clock(clock),
	.reset_n(reset_n),
	.uart_rx(uart_rx),
	
	.uart_tx(uart_tx)
);
localparam DEFAULT_OUTPUT = 8'd0;

localparam CLOCK_HZ = 50_000_000;
localparam BAUD_RATE = 115_200;

localparam CLKS_PER_BIT = CLOCK_HZ / BAUD_RATE; // 434
localparam HALF_BIT_CLKS = CLKS_PER_BIT / 2;   // 217

task uart_tx_check_sentData;
	input [7:0] expected_data;
	integer i;

	begin

		repeat(HALF_BIT_CLKS) @(posedge clock);
		#1;
		
		if(1'b0 !== uart_tx) begin
			errors = errors + 1;
			$display("FAILED start bit. Expected tx: 1'b0, actual tx: %b",uart_tx); 
		end
		else $display("PASSED start bit. tx: %b",uart_tx);
		
	
		for(i = 0; i<8; i =i+1) begin
			repeat(CLKS_PER_BIT) @(posedge clock);
			#1;
			if(expected_data[i] !== uart_tx) begin
				errors = errors + 1;
				$display("FAILED. Expected tx: %b, actual tx: %b",expected_data[i],uart_tx); 
			end
			else $display("PASSED. tx: %b",uart_tx);
		end

		repeat(CLKS_PER_BIT) @(posedge clock);
		#1;
		if(1'b1 !== uart_tx) begin
			errors = errors + 1;
			$display("FAILED stop bit. Expected tx: 1'b1, actual tx: %b",uart_tx); 
		end
		else $display("PASSED stop bit. tx: %b",uart_tx);
			
	end
endtask	


task uart_rx_send_data;
	input [7:0] data;
	integer j;

	begin
		uart_rx = 1'b0;
		repeat(CLKS_PER_BIT) @(posedge clock);
		#1;
	
		for(j = 0; j<8; j =j+1) begin
			uart_rx= data[j];
			repeat(CLKS_PER_BIT) @(posedge clock);
			#1;
		end
		
		uart_rx = 1'b1;
		repeat(CLKS_PER_BIT) @(posedge clock);
		#1;		
	end
endtask

task uart_rx_data_check;
	input [7:0] expected_rx_data;
	
	begin
	
	if(rx_data !== expected_rx_data) begin
		$display("FAILED, Time = %t, rx_data = %b, exp_rx_data = %b", $time, rx_data, expected_rx_data); 
		errors = errors + 1;
	end
	else 
		$display("PASSED, Time = %t, rx_data = %b", $time, rx_data); 
	end
	
endtask

task fifo_read_and_check;
    input [7:0] expected_read_data;

    begin

        if (read_data !== expected_read_data) begin
            errors = errors + 1;
            $display("FAILED, Time = %t, read_data = %h, expected = %h", $time, read_data, expected_read_data);
        end
        else begin
            $display("PASSED, Time = %t, read_data = %h", $time, read_data);
        end
    end
endtask

task moving_average_check_result;
    input [7:0] expected_result;

    begin
        if (result !== expected_result) begin
            errors = errors + 1;
            $display("FAILED, Time = %t, result = %0d, expected = %0d", $time, result, expected_result);
        end
        else begin
            $display("PASSED, Time = %t, result = %0d",$time, result);
        end
    end
endtask

task uart_send_and_check;
    input [7:0] send_data;
    input [7:0] expected_rx_fifo_data;
    input [7:0] expected_result;

    begin
        fork
            uart_rx_send_data(send_data);

            begin
				@(posedge rx_valid);
				#1;
				uart_rx_data_check(expected_rx_fifo_data);

				@(posedge data_valid);
				#1;
				fifo_read_and_check(expected_rx_fifo_data);

				@(posedge result_valid);
				#1;
				moving_average_check_result(expected_result);

				wait (tx_busy == 1'b1);
				uart_tx_check_sentData(expected_result);

				// Wait for TX to finish before returning
				wait (tx_busy == 1'b0);
            end
        join
    end
endtask

initial begin
	clock = 1'b0;
	
	forever begin
	#10; clock = ~clock;
	end

end
initial begin
    #2_000_000; // 1 ms
    $fatal(1, "TIMEOUT: test did not finish");
end

initial begin
	reset_n = 1'b0;
	uart_rx = 1'b1;
	errors = 0;
	
	repeat(5) @(posedge clock);
	#1;
	reset_n = 1'b1;
	$display("Check default outputs");
	uart_rx_data_check(DEFAULT_OUTPUT);
	fifo_read_and_check(DEFAULT_OUTPUT);
	moving_average_check_result(DEFAULT_OUTPUT);
	for(k = 0; k<CLKS_PER_BIT; k =k+1) begin
		@(posedge clock);
		#1;
		if(uart_tx !== 1'b1) begin
			errors = errors + 1;
			$display("Incorrect transmission after reset");
		end
	end
	
	$display("Send data1 then check");
	uart_send_and_check(8'd4,8'd4,8'd1); //4 + 3* 0 / 4= 1
	$display("Send data2 then check");
	uart_send_and_check(8'd12,8'd12,8'd4); //4 + 12 + 2* 0 / 4= 4

	$display("Send data3 then check");	
	uart_send_and_check(8'd8,8'd8,8'd6); //4 + 12 + 8 + 1* 0 / 4= 6

	$display("Send data4 then check");
	uart_send_and_check(8'd2,8'd2,8'd6); //4 + 12 + 8 + 2 / 4= 6
	
	$display("Send data5 then check");
	uart_send_and_check(8'd6,8'd6,8'd7); //12 + 8 + 2 + 6 / 4= 7
	
	reset_n = 1'b0;
	@(posedge clock);
	#1;
	reset_n = 1'b1;
	
	$display("Test function after reset");
	uart_send_and_check(8'd4,8'd4,8'd1); //4 + 3* 0 / 4= 1	
		
	$display("Simulation finished: %0d errors", errors);	
	$finish;	

end
endmodule