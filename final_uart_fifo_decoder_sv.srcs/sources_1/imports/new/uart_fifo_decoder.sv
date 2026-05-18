`timescale 1ns / 1ps

module uart_fifo_decoder (
    input  logic clk,
    input  logic rst,
    input  logic rx,
    output logic dataU,
    output logic dataR,
    output logic dataD,
    output logic dataL
);

    logic [7:0] w_rx_data, w_pop_data;
    logic w_rx_done, w_empty;

    uartrx_sv U_UARTRX (
        .clk    (clk),
        .rst    (rst),
        .rx     (rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );


    fifo_sv U_FIFORX (
        .clk      (clk),
        .rst      (rst),
        .push_data(w_rx_data),
        .push     (w_rx_done),
        .pop      (~w_empty),
        .pop_data (w_pop_data),
        .empty    (w_empty),
        .full     (full)
    );


    ascii_decoder_sv U_DECODER (
        .clk         (clk),
        .rst         (rst),
        .d_ascii_data(w_pop_data),
        .dec_start   (~w_empty),
        .dataU (dataU),
        .dataR (dataR),
        .dataD (dataD),
        .dataL (dataL)
    );

endmodule


// ===========================================================================
// ===========================================================================
module uartrx_sv (
    input clk,
    input rst,
    input rx,
    output [7:0] rx_data,
    output rx_done
);

    logic w_b_tick;
    // =============================

    // UART RX
    // ============================= 
    baud_tick_gen U_BAUD_TICK_GEN (
        .clk     (clk),
        .rst     (rst),
        .o_b_tick(w_b_tick)
    );

    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .b_tick (w_b_tick),
        .rx     (rx),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

endmodule
// ======================================================
// tick generator 
// ======================================================
module baud_tick_gen (
    input  logic clk,
    input  logic rst,
    output logic o_b_tick
);

    // Parameter for Baudrate and Count value
    // BAUDRATE x 16 to rx can receive data safely
    parameter BAUDRATE = 9600 * 16;
    parameter F_COUNT = 100_000_000 / BAUDRATE;
    parameter BIT_WIDTH = $clog2(F_COUNT);

    // Inner counter
    logic [BIT_WIDTH-1:0] counter_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_b_tick    <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            o_b_tick    <= 1'b0;
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                o_b_tick    <= 1'b1;
            end
        end
    end

endmodule

// ======================================================
// UART RX module
// ======================================================
module uart_rx (
    input  logic       clk,
    input  logic       rst,
    input  logic       b_tick,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    // State
    parameter [1:0] IDLE = 0;
    parameter [1:0] START = 1;
    parameter [1:0] DATA = 2;
    parameter [1:0] STOP = 3;

    logic [1:0] c_state, n_state;

    // register to count tick
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    // register to count input bit num
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    // register to receive data
    logic [7:0] data_reg, data_next, rx_data_next;
    // register to make rx done signal
    logic rx_done_reg, rx_done_next;
    assign rx_done = rx_done_reg;

    // Update Logic (SL)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state        <= IDLE;
            b_tick_cnt_reg <= 5'b0_0000;
            bit_cnt_reg    <= 3'b000;
            data_reg       <= 8'b0000_0000;
            rx_done_reg    <= 1'b0;
            rx_data        <= 0;
        end else begin
            c_state        <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            data_reg       <= data_next;
            rx_done_reg    <= rx_done_next;
            rx_data        <= rx_data_next;
        end
    end

    // Next State & Output Logic (CL)
    always_comb begin
        n_state         = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        data_next       = data_reg;
        rx_done_next    = rx_done_reg;
        rx_data_next    = rx_data;

        case (c_state)
            IDLE: begin
                rx_done_next = 1'b0;
                if (b_tick && ~rx) begin
                    b_tick_cnt_next = 0;
                    n_state         = START;
                end
            end

            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                        n_state         = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        data_next       = {rx, data_reg[7:1]};
                        b_tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 0;
                            n_state         = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            STOP: begin
                if (b_tick) begin
                    if ((b_tick_cnt_reg == 23) || (b_tick_cnt_reg > 15 && ~rx)) begin
                        n_state = IDLE;
                        rx_done_next = 1'b1;
                        rx_data_next = data_reg;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule

// ===========================================================================
// ===========================================================================
module fifo_sv (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] push_data,
    input  logic       push,
    input  logic       pop,
    output logic [7:0] pop_data,
    output logic       empty,
    output logic       full
);
    logic [3:0] w_wptr, w_rptr;

    // .*, 을 사용하면 알아서 이름 매핑
    reg_file U_REG_FILE (
        .*,
        .wdata(push_data),
        .we   (~full&push),
        .waddr(w_wptr),
        .raddr(w_rptr),
        .rdata(pop_data)
    );

    control_unit U_CNT_UNIT (
        .*,
        .wptr(w_wptr),
        .rptr(w_rptr)
    );

endmodule

module reg_file (
    input  logic       clk,
    input  logic [7:0] wdata,
    input  logic       we,
    input  logic [3:0] waddr,
    input  logic [3:0] raddr,
    output logic [7:0] rdata
);
    logic [7:0] reg_file[0:15];

    always_ff @(posedge clk) begin
        if (we) begin  // write scenario
            reg_file[waddr] <= wdata;
        end
    end

    // combinational logic
    // read address -> read data output decision
    assign rdata = reg_file[raddr];
endmodule

module control_unit (
    input logic clk,
    input logic rst,
    input logic push,
    input logic pop,
    output logic full,
    output logic empty,
    output logic [3:0] wptr,
    output logic [3:0] rptr
);
    logic [3:0] wptr_reg, wptr_next;
    logic [3:0] rptr_reg, rptr_next;
    logic full_reg, full_next;
    logic empty_reg, empty_next;

    assign full  = full_reg;
    assign empty = empty_reg;
    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            wptr_reg  <= 0;
            rptr_reg  <= 0;
            full_reg  <= 0;
            empty_reg <= 1;
        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always_comb begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;

        case ({
            push, pop
        })
            // do not need initialize
            // only push
            2'b10: begin
                // not full 
                if (!full_reg) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                    if (wptr_next == rptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end

            // pop only
            2'b01: begin
                // not empty
                if (!empty_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                    if (rptr_next == wptr_reg) begin
                        empty_next = 1'b1;
                    end
                end
            end

            // push pop 
            2'b11: begin
                // full state -> only pop
                if (full_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 1'b0;
                end  // empty state -> only push
                else if (empty_reg) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end  // not full, empty state -> pop, push
                else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end
endmodule

// ===========================================================================
// ===========================================================================
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