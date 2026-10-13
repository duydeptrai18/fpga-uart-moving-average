/*
- This moving_average will receive a byte sample then calculate the moving average.
- It uses a control index to keep track of the oldest sample.
- Intially before 4 valid samples are loaded into the processor, 4 zeros are used as the initial inputs.
- When the 1st,2nd,3rd valid samples are loaded in, it will assume zeroes as the valid samples.
- For example: when 4 is first loaded in as the first valid sample, result = (4+0+0+0)/4 = 1.
- If a result is only desired when the first 4 valid samples are loaded in, a counter counting to 4 should be implemented.
*/

module moving_average(
	input clock,
	input reset_n,
	input [7:0] data,
	input data_valid,
	output reg [7:0] result,
	output reg result_valid
);
localparam DEFAULT_OUTPUT = 8'd0;

integer i;
reg [9:0] sum;
reg[7:0] registers [0:3];
reg [1:0] index;


always @(posedge clock or negedge reset_n) begin
	if(!reset_n) begin
		result <= DEFAULT_OUTPUT;
		result_valid <= 1'b0;
		index <= 2'd0;
		registers[0] <= 8'd0;
		registers[1] <= 8'd0;
		registers[2] <= 8'd0;
		registers[3] <= 8'd0;		
	end

	else begin
		result_valid <= 1'b0;

		if(data_valid) begin
		
			sum = {2'b00, data};//sum can become a 10-bit value
			for(i = 0; i<4; i = i+1) begin
				if(i!=index) 
					sum = sum + registers[i];
			end
			
			result <= sum / 4;
			registers[index] <= data;
			index <= index + 2'd1;
			result_valid <= 1'b1;
		end
	end
end

endmodule