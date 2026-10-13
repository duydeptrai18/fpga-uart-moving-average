/*
- This transmitter is implemented by a FSM with 4 states (IDLE, START, DATA, STOP) that follows the UART 8N1 protocol.
- In Idle state, it will transmit bit 1 until tx_start comes, then it will go to Start state, and tx_busy = 1.
- In Start state, it will transmit bit 0 for CLKS_PER_BIT cycles.
- In Data state, it will transmit data bit starting from LSB to MSB, each for CLKS_PER_BIT cycles.
- In Stop state, it will transmit bit 1 for CLKS_PER_BIT cycles. Then it will go back to idle state, and tx_busy = 0.

*/

module uart_tx(
	input clock,
	input reset_n,
	input [7:0] tx_data,
	input tx_start,
	
	output reg tx,
	output reg tx_busy
);
localparam CLOCK_HZ = 50_000_000;
localparam BAUD_RATE = 115_200;

localparam CLKS_PER_BIT = CLOCK_HZ / BAUD_RATE; // 434
localparam HALF_BIT_CLKS = CLKS_PER_BIT / 2;   // 217

localparam IDLE = 2'b00;
localparam START = 2'b01;
localparam DATA = 2'b10;
localparam STOP = 2'b11;

reg [7:0] tx_data_temp;
reg [1:0] state;
reg [31:0] counter;
reg [2:0] bit_index;

always @(posedge clock or negedge reset_n) begin

	if(!reset_n) begin
		counter <= 32'd0;
		tx <= 1'b1;
		tx_busy <= 1'b0;
		state <= IDLE;
		tx_data_temp <= 8'd0;
		bit_index <=3'd0;
	end

	else begin
	
	case (state) 
	
	IDLE: begin
		counter <= 32'd0;
		tx <= 1'b1;
		tx_busy <= 1'b0;
		state <= IDLE;
		bit_index <= 3'd0;
		if(tx_start == 1'b1) begin
			tx <= 1'b0;
			tx_data_temp <= tx_data;
			tx_busy <= 1'b1;
			state <= START;
		end
	
	end
	
	START: begin
		tx <= 1'b0;
		tx_busy <= 1'b1;
		state <= START;
		bit_index <= 3'd0;
		counter <= counter + 1'b1;
		if(counter == CLKS_PER_BIT - 1) begin
			tx <= tx_data_temp[0];
			state <= DATA;
			counter <= 32'd0;
		end
		
	end
	
	DATA: begin
		tx <= tx_data_temp[bit_index];
		tx_busy <= 1'b1;
		state <= DATA;
		bit_index <= bit_index;
		counter <= counter + 1'b1;
		
		if(counter == CLKS_PER_BIT - 1) begin
			counter <= 32'd0;
			bit_index <= bit_index + 1'b1;
			if(bit_index == 3'd7) begin
				tx <= 1'b1;
				state <= STOP;
			end
			else begin
				tx <= tx_data_temp[bit_index + 1];
			end
		end
	end
	
	
	STOP: begin
		counter <= counter + 1'b1;
		tx <= 1'b1;
		tx_busy <= 1'b1;
		state <= STOP;
		bit_index <= 3'd0;

		if(counter == CLKS_PER_BIT - 1) begin
			state <= IDLE;
			counter <= 32'd0;
			tx_busy <= 1'b0;
		end
	end
	
	default: begin
		counter <= 32'd0;
		tx <= 1'b1;
		tx_busy <= 1'b0;
		state <= IDLE;
		bit_index <= 3'd0;
	end

	endcase
	end
end

endmodule