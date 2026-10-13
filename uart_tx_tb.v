/*
TEST CASES:
1. Reset:
   - Verify TX is HIGH (idle) and tx_busy is LOW.

2. Transmit DATA1:
   - Verify TX goes LOW and tx_busy goes HIGH when transmission starts.
   - Check the start bit, all 8 data bits (LSB first), and stop bit
     at their midpoints.
   - Verify TX remains HIGH and tx_busy returns LOW after completion.

3. Transmit DATA2 while changing tx_data:
   - Start transmitting DATA2.
   - Change tx_data to DATA3 during transmission.
   - Verify the transmitted frame still contains DATA2, confirming
     that TX saves the input byte when transmission starts.
   - Verify tx_busy remains HIGH at the stop-bit midpoint.

Each failed check increments the error counter.
The total error count is printed at the end of simulation.
*/
`timescale 1ns/1ps 
module uart_tx_tb;
	reg clock;
	reg reset_n;
	reg [7:0] tx_data;
	reg tx_start;
	
	wire tx;
	wire tx_busy;
	integer errors;

uart_tx uart_tx_dut(
	.clock(clock),
	.reset_n(reset_n),
	.tx_data(tx_data),
	.tx_start(tx_start),
	
	.tx(tx),
	.tx_busy(tx_busy)
);

localparam CLOCK_HZ = 50_000_000;
localparam BAUD_RATE = 115_200;

localparam CLKS_PER_BIT = CLOCK_HZ / BAUD_RATE; // 434
localparam HALF_BIT_CLKS = CLKS_PER_BIT / 2;   // 217

initial begin
	clock = 1'b0;
	
	forever begin
	#10; clock = ~clock;
	end

end

task uart_tx_check_busy;
	input expected_tx_busy;
	
	begin
	
		if(tx_busy !== expected_tx_busy) begin
			$display("FAILED, Time = %t, tx_busy = %b, exp_tx_busy = %b", $time, tx_busy, expected_tx_busy); 
			errors = errors + 1;
		end
		else
			$display("PASSED, Time = %t, tx_busy = %b", $time, tx_busy); 
	end
	
endtask

task uart_tx_check;
	input expected_tx;
	
	begin
	
		if(tx !== expected_tx) begin
			$display("FAILED, Time = %t, tx = %b, exp_tx = %b", $time, tx, expected_tx); 
			errors = errors + 1;
		end
		else 
			$display("PASSED, Time = %t, tx = %b", $time, tx); 
	end
	
endtask

task uart_tx_check_sentData;
	input [7:0] expected_data;
	integer i;

	begin

		repeat(HALF_BIT_CLKS) @(posedge clock);
		#1;
		
		uart_tx_check(1'b0); //check mid point of start bit = 0.
		uart_tx_check_busy(1'b1);
		
	
		for(i = 0; i<8; i =i+1) begin
			repeat(CLKS_PER_BIT) @(posedge clock);
			#1;
			uart_tx_check(expected_data[i]);
		end

		repeat(CLKS_PER_BIT) @(posedge clock);
		#1;
		uart_tx_check(1'b1);  //check mid point of stop bit = 1.
		uart_tx_check_busy(1'b1);
			
	end
endtask	


localparam DATA1 = 8'b10011001;
localparam DATA2 = 8'b00010000;
localparam DATA3 = 8'b11000001;
initial begin
	errors = 0;
	reset_n = 1'b0;
	tx_data = 8'b00000000;
	tx_start = 1'b0;

	#3;	
	$display("check after reset");
	uart_tx_check(1'b1);
	uart_tx_check_busy(1'b0);
	
	#1;
	$display("set up before data1 sending starts next posedge");
	tx_data = DATA1;
	tx_start = 1'b1;
	reset_n = 1'b1;
	
	@(posedge clock);
	#1;
	$display("sending data1 begins");
	uart_tx_check(1'b0);
	uart_tx_check_busy(1'b1);
	tx_start = 1'b0;
	
	$display("check sending data1");	
	uart_tx_check_sentData(DATA1);

	repeat (CLKS_PER_BIT) @(posedge clock);
	#1;
	$display("check mid point of first idle bit after done = 1.");
	uart_tx_check(1'b1);  
	uart_tx_check_busy(1'b0);
	
	$display("set up before data2 sending starts next posedge");
	tx_data = DATA2;
	tx_start = 1'b1;

	@(posedge clock);
	#1;
	$display("sending data2 begins");
	uart_tx_check(1'b0);
	uart_tx_check_busy(1'b1);
	tx_start = 1'b0;

	$display("running uart_tx_check_sentData(DATA2); and the begin - end block inside fork - join concurrently.");
	fork 
		$display("check sending data2");	
		uart_tx_check_sentData(DATA2);	
		
		begin
			repeat (CLKS_PER_BIT) @(posedge clock);
			#1;
			tx_data = DATA3;//try changing sent data here
		
		end
	join

	$display("Simulation finished: %0d errors", errors);
	
	$finish;
end

endmodule