`timescale 1ns / 1ps

module ascii_decoder_sv (
    input logic clk,
    input logic rst,
    input logic [7:0] d_ascii_data,
    input logic dec_start,
    output logic dataU,  //8'h55  
    output logic dataR,  //8'h52
    output logic dataD,  //8'h44
    output logic dataL   //8'h4c
);

	// param for state
	parameter IDLE = 0;
	parameter DECODE = 1;

	logic c_state, n_state;
	logic [7:0] d_ascii_data_reg, d_ascii_data_next;

	// wire
	logic data_is_u, data_is_r, data_is_d, data_is_l;

	assign data_is_u = (d_ascii_data_reg == 8'h75) | (d_ascii_data_reg == 8'h55);
	assign data_is_r = (d_ascii_data_reg == 8'h72) | (d_ascii_data_reg == 8'h52);
	assign data_is_d = (d_ascii_data_reg == 8'h64) | (d_ascii_data_reg == 8'h44);
	assign data_is_l = (d_ascii_data_reg == 8'h6C) | (d_ascii_data_reg == 8'h4C);

	always_ff @(posedge clk or posedge rst) begin
		if (rst) begin
			c_state <= IDLE;
			d_ascii_data_reg <= 0;
		end
		else begin
			c_state <= n_state;
			d_ascii_data_reg <= d_ascii_data_next;
		end
	end

	always_comb begin
		n_state = c_state;
		d_ascii_data_next = d_ascii_data_reg;

		case (c_state)
			IDLE: begin
				if (dec_start) begin
					n_state = DECODE;
					d_ascii_data_next = d_ascii_data;
				end
			end
			DECODE: begin
				n_state = IDLE;
				d_ascii_data_next = 0;
			end
		endcase
	end

	// output logic
	assign dataU = ((c_state == DECODE) & data_is_u) ? 1'b1 : 1'b0;
	assign dataR = ((c_state == DECODE) & data_is_r) ? 1'b1 : 1'b0;
	assign dataD = ((c_state == DECODE) & data_is_d) ? 1'b1 : 1'b0;
	assign dataL = ((c_state == DECODE) & data_is_l) ? 1'b1 : 1'b0;

endmodule