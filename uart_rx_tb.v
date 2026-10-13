/* 
TEST CASES:
1. Default-state recovery:
   - Start without asserting reset.
   - Verify the default-state branch initializes rx_data to zero
     and clears rx_valid after the first clock edge.

2. Normal reception:
   - Send DATA1 and verify the received byte.
   - Verify rx_valid clears on the following clock edge.

3. Reset:
   - Assert reset and verify rx_data is zero and rx_valid is LOW.

4. All-ones reception:
   - Send DATA2 (8'hFF) and verify the received byte.

5. Back-to-back reception:
   - Send DATA3 immediately after DATA2's stop bit,
     with no additional idle time.
   - Verify the received byte.

6. Invalid stop bit:
   - Send DATA4 with a LOW stop bit.
   - Verify DATA3 is retained and rx_valid remains LOW.
   - The receiver should enter RECOVERY.

7. Reception after framing-error recovery:
   - Return RX HIGH, then send a valid DATA4 frame.
   - Verify normal reception resumes.

8. False-start rejection:
   - Drive RX LOW for only three clock cycles, then return HIGH.
   - Inspect the waveform to verify the receiver returns to IDLE
     after checking the start-bit midpoint.

9. Reception after a false start:
   - Send a valid DATA5 frame and verify normal reception resumes.

Valid-frame checks run concurrently with UART stimulus using fork/join.
Cases 6 and 8 require waveform inspection to confirm internal states.
Failed checks increment the error counter.
A 1 ms timeout detects a stalled test.

*/


`timescale 1ns/1ps 
module uart_rx_tb;
	reg clock;
	reg reset_n;
	reg rx;
	
	wire [7:0] rx_data;
	wire rx_valid;
	integer errors;

uart_rx uart_rx_dut(
	.clock(clock),
	.reset_n(reset_n),
	.rx(rx),
	
	.rx_data(rx_data),
	.rx_valid(rx_valid)
);

localparam RX_DEFAULT_DATA = 8'd0;

localparam CLOCK_HZ = 50_000_000;
localparam BAUD_RATE = 115_200;

localparam CLKS_PER_BIT = CLOCK_HZ / BAUD_RATE; // 434
localparam HALF_BIT_CLKS = CLKS_PER_BIT / 2;   // 217

initial begin
    #1_000_000; // 1 ms
    $fatal(1, "TIMEOUT: test did not finish");
end

task uart_rx_check_valid;
	input expected_rx_valid;
	
	begin
	
	if(rx_valid !== expected_rx_valid) begin
		$display("FAILED, Time = %t, rx_valid = %b, expected_rx_valid = %b", $time, rx_valid, expected_rx_valid); 
		errors = errors + 1;
	end
	else
		$display("PASSED, Time = %t, rx_valid = %b", $time, rx_valid); 
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

task uart_rx_send_data;
	input [7:0] data;
	integer j;

	begin
		rx = 1'b0;
		repeat(CLKS_PER_BIT) @(posedge clock);
		#1;
	
		for(j = 0; j<8; j =j+1) begin
			rx= data[j];
			repeat(CLKS_PER_BIT) @(posedge clock);
			#1;
		end
		
		rx = 1'b1;
		repeat(CLKS_PER_BIT) @(posedge clock);
		#1;		
	end
endtask

task uart_rx_send_only_data;
	input [7:0] data;
	integer j;

	begin

		for(j = 0; j<8; j =j+1) begin
			rx= data[j];
			repeat(CLKS_PER_BIT) @(posedge clock);
			#1;
		end
			
	end
endtask

task uart_rx_send_and_check;
    input [7:0] send_data;

    begin
        fork
            uart_rx_send_data(send_data);

            begin
				
				@(posedge rx_valid);
				#1;
				uart_rx_data_check(send_data); //check data at midpoint of stop bit
				uart_rx_check_valid(1'b1);

				@(posedge clock);
				#1;
				uart_rx_data_check(send_data);
				uart_rx_check_valid(1'b0);
            
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

localparam DATA1 = 8'b01001100;
localparam DATA2 = 8'hFF;
localparam DATA3 = 8'd1;
localparam DATA4 = 8'd2;
localparam DATA5 = 8'd3;

initial begin
	errors = 0;
	rx = 1'b1;
	reset_n = 1'b1;
	
	//1. Test Default-------------------
	@(posedge clock); //default should execute after this edge
	#1;
	$display("Check after default");
	uart_rx_data_check(RX_DEFAULT_DATA);
	uart_rx_check_valid(1'b0);
	
	//idling for 5 cycles-------------
	rx = 1'b1; 
	repeat(5) @(posedge clock);
	#1;
	
	//2. Send DATA1 ------------
	$display("Send and check data1");
	uart_rx_send_and_check(DATA1);

	//3. Test Reset----------------------
	$display("Test Reset");
	reset_n = 1'b0; //reset and hold reset for 4 edges
	repeat(4) @(posedge clock);
	#1;
	uart_rx_data_check(RX_DEFAULT_DATA);
	uart_rx_check_valid(1'b0);	
	reset_n = 1'b1; //reset released
	#1;
	
	//4. Send data2---------------------
	$display("Send and check data2");
	uart_rx_send_and_check(DATA2);		
	
	//5. Send data3 without idling--------------
	$display("Send and check data3 without idling");
	uart_rx_send_and_check(DATA3);		

	//idling for 5 cycles-------------
	rx = 1'b1; 
	repeat(5) @(posedge clock);
	#1;

	//6. Send data4 but with low stop bit (-> hold previous data -data3)--------------
	$display("Send data4 but with low stop bit (-> hold previous data -data3)");
	rx = 1'b0; //start bit starts here
	repeat(CLKS_PER_BIT) @(posedge clock);
	#1;

	uart_rx_send_only_data(DATA4);
	
	rx = 1'b0; //stop bit
	repeat(HALF_BIT_CLKS+3) @(posedge clock);
	#1;
	uart_rx_data_check(DATA3); //check data at midpoint of stop bit
	uart_rx_check_valid(1'b0);
	
	@(posedge clock);
	#1;
	uart_rx_data_check(DATA3);
	uart_rx_check_valid(1'b0);	
		
	repeat(HALF_BIT_CLKS-1'd4) @(posedge clock); //finish the remaining part of stop bit
	#1;

	//go back to idling and idling for 5 cycles-------------
	rx = 1'b1; 
	repeat(5) @(posedge clock);
	#1;

	//7. Send data4 again to test function after recovery--------------
	$display("Send and check data4 to test function after recovery");
	uart_rx_send_and_check(DATA4);	

	//8. Send data5 but with a false pulse start bit -> sending will not be completed--------------
	$display("Send data5 but with a false pulse start bit -> sending will not be completed");
	rx = 1'b0; //start bit starts here
	repeat(3) @(posedge clock); // hold for only 3 cycles
	#1;

	rx = 1'b1; //go back to idling
	repeat(CLKS_PER_BIT - 3) @(posedge clock);
	#1;
	//Check in waveform to see the state at this point, it should go back to idle

	//idling for 5 cycles-------------
	rx = 1'b1; 
	repeat(5) @(posedge clock);
	#1;
	
	//9. Send data5 again to test function after false start--------------
	$display("Send and check data5 to test function after false start");
	uart_rx_send_and_check(DATA5);		

	if (errors == 0)
    		$display("ALL TESTS PASSED");
	else
    		$fatal(1, "Test failed: %0d errors", errors);

	$finish;	
	
end

endmodule