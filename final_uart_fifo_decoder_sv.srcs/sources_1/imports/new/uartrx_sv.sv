`timescale 1ns / 1ps

module uartrx_sv(
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