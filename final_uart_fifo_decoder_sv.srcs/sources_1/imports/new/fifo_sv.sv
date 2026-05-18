`timescale 1ns / 1ps

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
        .wptr (w_wptr),
        .rptr (w_rptr)
    );

endmodule

module reg_file (
    input logic         clk,
    input logic [7:0]   wdata,
    input logic         we,
    input logic [3:0]   waddr,
    input logic [3:0]   raddr,
    output logic [7:0]  rdata
);
    logic [7:0] reg_file [0:15];

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
    input  logic clk,
    input  logic rst,
    input  logic push,
    input  logic pop,
    output logic full,
    output logic empty,
    output logic [3:0] wptr,
    output logic [3:0] rptr
);
    logic [3:0] wptr_reg, wptr_next;
    logic [3:0] rptr_reg, rptr_next;
    logic full_reg, full_next;
    logic empty_reg, empty_next;

    assign full = full_reg;
    assign empty = empty_reg;
    assign wptr = wptr_reg;
    assign rptr = rptr_reg;

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
        wptr_next   = wptr_reg;
        rptr_next   = rptr_reg;
        full_next   = full_reg;
        empty_next  = empty_reg;
        
        case ({push, pop})
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
                end 
                // empty state -> only push
                else if (empty_reg) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 1'b0;
                end 
                // not full, empty state -> pop, push
                else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end
endmodule
