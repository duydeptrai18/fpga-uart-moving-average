/*
- This FIFO uses control indexes like write_position and read_position, and control flags like fifo_full and fifo_empty
to keep track of the current data.
- When write is enabled, size = size + 1, and write index moves up 1 position.
- When write is enabled, size = size - 1, and read index moves up 1 position.
- The FIFO will hold the previous data when no read has been requested. 
- The indexes will wrap around the array when it gets overflown, 
For example: When write_position = 15, and write is enabled, write_position = 0, and start at the beginning of the array.
- Read is not allowed when the fifo is empty.
- Write is not allowed when the fifo is full.

*/

module fifo(
	input clock,
	input reset_n,
	input write_enable,
	input read_enable,
	input [7:0] write_data,
	output reg [7:0] read_data,
	output fifo_full,
	output fifo_empty
);

localparam RX_DEFAULT_DATA = 8'd0;
localparam FIFO_SIZE = 5'd16;

reg [4:0] size;
reg [7:0] memory [0: FIFO_SIZE-1];
reg [3:0] write_position;
reg [3:0] read_position;
wire safe_read_enable = read_enable & !fifo_empty;
wire safe_write_enable = write_enable & (!fifo_full | safe_read_enable);
assign fifo_full = (size == FIFO_SIZE);
assign fifo_empty = (size == 5'd0);

always @(posedge clock or negedge reset_n) begin
	if(!reset_n) begin
		size <= 5'd0;
		//clear memory is not needed because the size and write_position and read_position will make reading invalid data not possible.
		write_position <= 4'd0;
		read_position <= 4'd0;	
		read_data <=  RX_DEFAULT_DATA;	

	end
	
	else begin
		if(safe_write_enable & !safe_read_enable) size <= size + 5'd1;
		else if(!safe_write_enable & safe_read_enable) size <= size - 5'd1;
			
		if(safe_write_enable) begin
			memory[write_position] <= write_data;
			write_position <= write_position + 4'd1;
		end
		
		if(safe_read_enable) begin
			read_data <= memory[read_position];
			read_position <= read_position + 4'd1;			
		end	
	end
end

endmodule