/*
TEST CASES:
1. Initial reset:
   - Verify result is zero and result_valid is LOW.

2. Zero-filled startup:
   - Send 4, 8, and 5.
   - Verify averages of 1, 3, and 4.
   - Verify result_valid is HIGH for each result.
   - The 17/4 calculation checks integer truncation.

3. Result-valid pulse:
   - After the first sample, verify result_valid clears on the
     next clock edge when data_valid is LOW.

4. Full window and oldest-sample replacement:
   - Send 3 and verify the average is 5.
   - Send 12, replacing the oldest sample (4), and verify
     the average is 7.

5. Reset after processing:
   - Assert reset after several samples.
   - Verify result returns to zero and result_valid is LOW.

6. Maximum sum:
   - Send four samples of 255.
   - Verify the final average is 255, and a sum of 1020
     that requires 10 bits.

7. Invalid input:
   - Change data to 30 while data_valid is LOW.
   - Verify result holds the previous average of 255.

Failed checks increment the error counter.
The total error count is printed at the end of simulation.
*/
`timescale 1ns/1ps 
module moving_average_tb;
    reg clock;
    reg reset_n;
    reg [7:0] data;
    reg data_valid;

    wire [7:0] result;
    wire result_valid;
	 integer errors;

localparam DEFAULT_OUTPUT = 8'd0;
	 
moving_average moving_average_dut(
	.clock(clock),
	.reset_n(reset_n),
	.data(data),
	.data_valid(data_valid),
	.result(result),
	.result_valid(result_valid)
);

initial begin
	clock = 1'b0;
	
	forever begin
	#10; clock = ~clock;
	end

end

task moving_average_write;
	input [7:0] test_data;
	
	begin
	
		@(negedge clock);
		data = test_data;
		data_valid = 1'b1;
		@(posedge clock);
		#1;
		data_valid = 1'b0;
	
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

task moving_average_check_result_valid;
    input expected_result_valid;

    begin
        if (result_valid !== expected_result_valid) begin
            errors = errors + 1;
            $display("FAILED, Time = %t, result_valid = %b, expected = %b", $time, result_valid, expected_result_valid);
        end
        else begin
            $display("PASSED, Time = %t, result_valid = %b",$time, result_valid);
        end
    end
endtask

initial begin
	errors = 0;
   reset_n = 1'b0;
   data = 8'd0;
   data_valid = 1'b0;
	
	@(posedge clock);
	#1;
	
	reset_n = 1'b1;
	
	$display("Test reset");
	moving_average_check_result(DEFAULT_OUTPUT);
	moving_average_check_result_valid(1'b0);
	
	$display("Write input data1 then check");
	moving_average_write(8'd4);	
	moving_average_check_result(8'd1); //4 + 3*0 / 4 =1;
	moving_average_check_result_valid(1'b1);
	
	@(posedge clock);
	#1;
	moving_average_check_result_valid(1'b0);//result_valid should go down after the edge	

	$display("Write input data2 then check");
	moving_average_write(8'd8);	
	moving_average_check_result(8'd3); //4 + 8 + 2*0 / 4 =3;
	moving_average_check_result_valid(1'b1);

	$display("Write input data3 then check");	
	moving_average_write(8'd5);	
	moving_average_check_result(8'd4); //4 + 8 + 5 + 0 / 4 = 4;
	moving_average_check_result_valid(1'b1);

	$display("Write input data4 then check");
	moving_average_write(8'd3);	
	moving_average_check_result(8'd5); //4 + 8 + 5 + 3 / 4 = 5;
	moving_average_check_result_valid(1'b1);	

	$display("Write input data5 then check");	
	moving_average_write(8'd12);	
	moving_average_check_result(8'd7); //12 + 8 + 5 + 3 / 4 = 7;
	moving_average_check_result_valid(1'b1);
	
	//Test reset the samples back to their default values
	reset_n = 1'b0;
	@(posedge clock);
	#1;
	reset_n = 1'b1;
	$display("Test reset the samples back to their default values");
	moving_average_check_result(DEFAULT_OUTPUT);
	moving_average_check_result_valid(1'b0);
	
	//test when the sum is a 10-bit value
	$display("test when the sum is a 10-bit value");
	moving_average_write(8'd255);	
	moving_average_write(8'd255);	
	moving_average_write(8'd255);	
	moving_average_write(8'd255);	
	moving_average_check_result(8'd255); 
	moving_average_check_result_valid(1'b1);
	
   data = 8'd30;//	try writing with data_valid = 0;
	$display("try writing with data_valid = 0");
	@(posedge clock);
	#1;
	moving_average_check_result(8'd255);
	
	$display("Simulation finished: %0d errors", errors);	
	$finish;
	
end
endmodule




	