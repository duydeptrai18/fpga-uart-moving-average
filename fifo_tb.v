/*
TEST CASES:
1. Reset:
   - Verify the FIFO is empty and not full after reset.

2. Single-byte write and read:
   - Write 1 and verify the FIFO becomes non-empty.
   - Read 1 and verify the FIFO becomes empty.

3. Read while empty:
   - Verify read_data holds the previous byte (1).
   - Verify the FIFO remains empty and not full.

4. Write disabled:
   - Change write_data to 10 while write_enable is LOW.
   - Verify no byte is queued and read_data remains unchanged.

5. Fill FIFO and do pointer wraparound:
   - Write 16 bytes with values 0 through 15.
   - Verify the FIFO becomes full and non-empty.

6. Simultaneous read/write while full:
   - Read the oldest byte (0) while writing 30.
   - Verify the FIFO remains full.

7. Write while full without a read:
   - Attempt to write 20.
   - Verify the FIFO remains full.
   - Read 1 and verify the FIFO is no longer full.

8. Drain FIFO and verify ordering:
   - Read values 2 through 15, followed by 30.
   - Verify the rejected value 20 does not appear.
   - Verify the FIFO becomes empty and not full.

Failed checks increment the error counter.
The total error count is printed at the end of simulation.
*/

`timescale 1ns/1ps
module fifo_tb;
	reg clock;
	reg reset_n;
	reg write_enable;
	reg read_enable;
	reg [7:0] write_data;
	wire [7:0] read_data;
	wire fifo_full;
	wire fifo_empty;
	integer errors;
	integer i;
	integer j;
	
fifo fifo_dut(
    .clock(clock),
    .reset_n(reset_n),
    .write_enable(write_enable),
    .read_enable(read_enable),
    .write_data(write_data),
    .read_data(read_data),
    .fifo_full(fifo_full),
    .fifo_empty(fifo_empty)
);

initial begin
	clock = 1'b0;
	
	forever begin
	#10; clock = ~clock;
	end

end

task fifo_write;

	input [7:0] test_write_data; 
	begin		
		@(negedge clock);
		write_enable = 1'b1;
		write_data = test_write_data;
		
		@(posedge clock);
		#1;
		write_enable = 1'b0;
	
	end
	
endtask

task fifo_read_and_check;
    input [7:0] expected_read_data;

    begin
        @(negedge clock);
        read_enable = 1'b1;

        @(posedge clock);
        #1;
        read_enable = 1'b0;

        if (read_data !== expected_read_data) begin
            errors = errors + 1;
            $display("FAILED, Time = %t, read_data = %h, expected = %h", $time, read_data, expected_read_data);
        end
        else begin
            $display("PASSED, Time = %t, read_data = %h", $time, read_data);
        end
    end
endtask

task fifo_check_flags;
    input expected_full;
    input expected_empty;

    begin
        if (fifo_full !== expected_full) begin
            errors = errors + 1;
            $display("FAILED, Time = %t, fifo_full = %b, expected = %b", $time, fifo_full, expected_full);
        end
        else begin
            $display("PASSED, Time = %t, fifo_full = %b", $time, fifo_full);
        end

        if (fifo_empty !== expected_empty) begin
            errors = errors + 1;
            $display("FAILED, Time = %t, fifo_empty = %b, expected = %b", $time, fifo_empty, expected_empty);
        end
        else begin
            $display("PASSED, Time = %t, fifo_empty = %b", $time, fifo_empty);
        end
    end
endtask

initial begin
	//1. Reset: verify the FIFO is empty and not full after reset.
	//reset begins first cycle
	errors = 0;
	write_enable = 1'b0;
	read_enable = 1'b0;
	write_data = 8'd0;
	reset_n = 1'b0;
	@(posedge clock);
	#1;
	reset_n = 1'b1;
	//reset ends first cycle
	
	//2. Single-byte write/read: verify data and empty/non-empty flags.
	//write then check
	$display("Write then check");
	fifo_check_flags(1'b0,1'b1); //not full, is empty
	fifo_write(8'd1);
	fifo_check_flags(1'b0,1'b0);	
	fifo_read_and_check(8'd1);
	fifo_check_flags(1'b0,1'b1);

	//3. Test reading when the fifo is empty -> it should hold the old read_data
	$display("Read while empty");	
	fifo_read_and_check(8'd1); 
	fifo_check_flags(1'b0,1'b1);
	
	//4. Write disabled: changing write_data must not input a new byte.
	@(negedge clock); //try writing with write_enable = 0
	$display("try writing with write_enable = 0");
	write_enable = 1'b0;
	write_data = 8'd10;
	
	fifo_read_and_check(8'd1);
	fifo_check_flags(1'b0,1'b1);	

	//5. Fill FIFO: write 0 through 15 and exercise pointer wraparound.
	$display("Fill FIFO: write 0 through 15 and exercise pointer wraparound.");
	for(i = 0; i<16; i =i+1) begin // [15 0 1 2 ... 14]
		fifo_write(i);
	end
	fifo_check_flags(1'b1,1'b0); //is full, not empty

	//6. Simultaneous read/write while full:
	//   Read the oldest byte (0), append 30, and remain full.
	//Now the fifo is full and write_position = read_position
	//Now try simulateneous read/write
	$display("now the fifo is full and write_position = read_position. now try simulateneous read/write");
	write_enable = 1'b1;
	write_data = 8'd30;
		
	fifo_read_and_check(8'd0);  // [15 30 1 2 ... 14]
	write_enable = 1'b0;
	fifo_check_flags(1'b1,1'b0); //is full, not empty	
	
	//7. Write while full without a read:
	//Reject 20; reading 1 afterward must free one slot.
	//Now try writing when fifo is full
	$display("now try writing when fifo is full");
	fifo_write(8'd20);
	fifo_check_flags(1'b1,1'b0); //is full, not empty
	fifo_read_and_check(8'd1);  // [15 30 1 2 ... 14], read now points at 2
	fifo_check_flags(1'b0,1'b0); 
	
	//8. Drain FIFO: verify 2 through 15, then 30, in order.
	//   Confirm the FIFO becomes empty after the final read.
	for(j = 2; j<16; j =j+1) begin
		fifo_read_and_check(j);
	end	

	fifo_read_and_check(8'd30);
	fifo_check_flags(1'b0,1'b1); //not full, is empty	
	

	//Print the total number of failed checks.
	$display("Simulation finished: %0d errors", errors);
	
	$finish;

end


endmodule

