/*
1. Send DATA1( normal num)
2. Send DATA2
3. Send DATA3(0)
4.Test changing the transmitted data while the transmitter is delivering the old data 

*/

`timescale 1ns/1ps
module uart_tx_rx_tb;
	reg clock;
	reg reset_n;
	reg [7:0] tx_data;
	reg tx_start;
	wire tx;
	wire tx_busy;
	
	wire [7:0] rx_data;
	wire rx_valid;
	integer errors;
	
localparam RX_DEFAULT_DATA = 8'd0;

localparam CLOCK_HZ = 50_000_000;
localparam BAUD_RATE = 115_200;

localparam CLKS_PER_BIT = CLOCK_HZ / BAUD_RATE; // 434
localparam HALF_BIT_CLKS = CLKS_PER_BIT / 2;   // 217

localparam DATA1 = 8'b01001100;
localparam DATA2 = 8'hFF;
localparam DATA3 = 8'd0;
localparam DATA4 = 8'd1;

uart_tx uart_tx_dut(
	.clock(clock),
	.reset_n(reset_n),
	.tx_data(tx_data),
	.tx_start(tx_start),
	
	.tx(tx),
	.tx_busy(tx_busy)
);

uart_rx uart_rx_dut(
	.clock(clock),
	.reset_n(reset_n),
	.rx(tx),
	
	.rx_data(rx_data),
	.rx_valid(rx_valid)
);

initial begin
    #1_000_000; // 1 ms
    $fatal(1, "TIMEOUT: loopback test did not finish");
end

task uart_send_and_check;
    input [7:0] expected_rx_data;
    input [7:0] test_tx_data;

    begin
			//Set inputs away from the next rising edge
        @(negedge clock);
        tx_data = test_tx_data;
        tx_start = 1'b1;

        @(posedge clock);
        #1;
        tx_start = 1'b0;

        @(posedge rx_valid);
        #1;

        if (rx_data !== expected_rx_data) begin
            errors = errors + 1;
            $display("FAILED, Time = %t, rx_data = %h, expected = %h", $time, rx_data, expected_rx_data);
        end 
		  else begin
            $display("PASSED, Time = %t, rx_data = %h", $time, rx_data);
        end

        @(posedge clock);
        #1;
        if (rx_valid !== 1'b0) begin
            errors = errors + 1;
            $display("FAILED: rx_valid did not clear");
        end

        // RX publishes before TX finishes its stop bit
        wait (tx_busy === 1'b0);
    end
endtask


initial begin
	clock = 1'b0;
	
	forever begin
	#10; clock = ~clock;
	end

end

initial begin
	errors = 0;
	tx_start = 1'b0;
	reset_n = 1'b0;
	
	@(posedge clock);
	#1;
	reset_n = 1'b1;
	
	uart_send_and_check(DATA1,DATA1); //1.
	uart_send_and_check(DATA2,DATA2); //2.
	uart_send_and_check(DATA3,DATA3); //3.
	
	
	
  //4. Test changing the transmitted data while the transmitter is delivering the old data 
  //-> it won't accept this new data and keep delivering the old data
  @(negedge clock);
  tx_data = DATA4;
  tx_start = 1'b1;

  @(posedge clock);
  #1;
  tx_start = 1'b0;
  
  repeat(CLKS_PER_BIT + HALF_BIT_CLKS) @(posedge clock);
  #1;
  tx_data = 8'd5;// change to the new data 1.5 bit period into the transmission   

  @(posedge rx_valid);
  #1;
  
  if (rx_data !== DATA4) begin
		 errors = errors + 1;
		 $display("FAILED: rx_data = %0d, expected = %0d",
					 rx_data, DATA4);
  end else begin
		 $display("PASSED: original byte retained");
  end
  
  wait (tx_busy === 1'b0);

  $display("Simulation finished: %0d errors", errors);
	
  $finish;
end
endmodule
