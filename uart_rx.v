/*
- The receiver is implemented by a FSM with 4 states (IDLE, START, DATA, STOP) that follows the UART 8N1 protocol.
- If no sample comes, the receiver will hold the previous data.
- When the sample comes, the receiver will check the start bit at mid point of the start bit period, and check every data bit 1 bit period from the point, 
then check the stop bit at the mid point of the stop bit period. If all is valid, it will output that byte, and rx_valid = 1 for 1 cycle, then go back down next cycle.
- If the start bit shows up initially but if it doesnt show at the check at the mid point, the receiver will go back to idle state.
- If the check at the mid point of the stop bit shows 0(incorrect), the receiver will enter recovery state,
and wait until it sees a 1 to go back to idle state, and the data that has been recorded will not be output(it will retain the old data). 

*/

module uart_rx(
	input clock,
	input reset_n,
	input rx,
	
	output reg [7:0] rx_data,
	output reg rx_valid
);
localparam RX_DEFAULT_DATA = 8'd0;

localparam CLOCK_HZ = 50_000_000;
localparam BAUD_RATE = 115_200;

localparam CLKS_PER_BIT = CLOCK_HZ / BAUD_RATE; // 434
localparam HALF_BIT_CLKS = CLKS_PER_BIT / 2;   // 217

localparam IDLE  = 3'b000;
localparam START = 3'b001;
localparam DATA  = 3'b010;
localparam STOP  = 3'b011;
localparam RECOVERY = 3'b100;

reg rx_temp;
reg rx_sync;

reg [7:0] rx_data_temp;
reg [2:0] state;
reg [31:0] counter;
reg [2:0] bit_index;

always @(posedge clock or negedge reset_n) begin
	if(!reset_n) begin
		rx_temp <= 1'b1;
		rx_sync <= 1'b1;
		rx_data <= RX_DEFAULT_DATA;
		rx_valid <= 1'b0;
		state <= IDLE;
		counter <= 32'd0;
		bit_index <= 3'd0;
		rx_data_temp <= RX_DEFAULT_DATA;
	end
	else begin
		rx_temp <= rx;
		rx_sync <= rx_temp;
		
		case(state)
		
		IDLE: begin
			rx_data_temp <= RX_DEFAULT_DATA;
			state <= IDLE;
			counter <= 32'd0;
			bit_index <= 3'd0;
			rx_valid <= 1'b0;
			
			if(!rx_sync) begin
				state<= START;
			end
		end
				
		START: begin

			counter <= counter + 1;
			
			if(counter == HALF_BIT_CLKS - 32'd1) begin
				counter <= 32'd0;
				if(rx_sync == 1'b0)  //mid point of start bit
					state <= DATA;
				
				else 
					state<= IDLE;
				
			end
		end
				
		DATA: begin
			counter <= counter + 1;
			
			if(counter == CLKS_PER_BIT - 32'd1) begin
				rx_data_temp[bit_index] <= rx_sync;
				counter <= 32'd0;
				if(bit_index == 3'd7) begin
					state <= STOP;
					bit_index <= 3'd0;
				end
				else 	bit_index <= bit_index + 1'b1;
			
			end
		end
		
		STOP: begin
			counter <= counter + 1;
			
			if(counter == CLKS_PER_BIT - 32'd1) begin
				counter <= 32'd0;
				if(rx_sync == 1'b1) begin //normal
					rx_valid <= 1'b1;
					rx_data <= rx_data_temp;
					state <= IDLE;
				end
				else begin
					state <= RECOVERY;
					rx_valid <= 1'b0;
					
				end
			end
		end
		
		RECOVERY: begin
			counter <= 32'd0;
			bit_index <= 3'd0;

			if (rx_sync == 1'b1) 
				state <= IDLE;
		end
		
		default: begin
			rx_data <= RX_DEFAULT_DATA;
			rx_valid <= 1'b0;
			state <= IDLE;
			counter <= 32'd0;
			bit_index <= 3'd0;
			rx_data_temp <= RX_DEFAULT_DATA;
		
		end
		endcase
		
	end
end
endmodule
