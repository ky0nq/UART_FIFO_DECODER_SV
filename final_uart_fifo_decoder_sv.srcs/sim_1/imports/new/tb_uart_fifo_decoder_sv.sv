`timescale 1ns / 1ps

class transaction;
    //rand bit [7:0] tx_data;
    randc bit [7:0] tx_data;
    bit            rx;
    bit            dataU;
    bit            dataR;
    bit            dataD;
    bit            dataL;
    bit            expect_U;
    bit            expect_R;
    bit            expect_D;
    bit            expect_L;

    function void expect_data();
        expect_U = (tx_data == 8'h55 || tx_data == 8'h75) ? 1'b1 : 1'b0;
        expect_R = (tx_data == 8'h52 || tx_data == 8'h72) ? 1'b1 : 1'b0;
        expect_D = (tx_data == 8'h44 || tx_data == 8'h64) ? 1'b1 : 1'b0;
        expect_L = (tx_data == 8'h4C || tx_data == 8'h6C) ? 1'b1 : 1'b0;
    endfunction

    function debug_print(string name);
        $display(
            "%t : [%s] ascii_data = %h, rx = %d, dataU = %h, dataD = %d, dataR = %h, dataL = %d",
            $time, name, tx_data, rx, dataU, dataD, dataR, dataL);
    endfunction
endclass

interface top_interface ();
    logic clk;
    logic rst;
    logic rx;
    logic dataU;
    logic dataR;
    logic dataD;
    logic dataL;
    logic rx_done;
endinterface

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event event_gen_next;

//    function new(mailbox#(transaction) gen2drv_mbox,
//                 mailbox#(transaction) gen2scb_mbox, event event_gen_next);
//        this.gen2drv_mbox   = gen2drv_mbox;
//        this.gen2scb_mbox   = gen2scb_mbox;
//        this.event_gen_next = event_gen_next;
//    endfunction//

//    task run(int count);
//        $display("========================================");
//        $display("[GEN] Start : total %0d transactions", count);
//        $display("========================================");
//        repeat (count) begin
//            tr = new;
//            tr.randomize();
//            tr.expect_data();
//            tr.debug_print("GEN");
//            gen2drv_mbox.put(tr);
//            gen2scb_mbox.put(tr);
//            @(event_gen_next);
//        end
//        $display("----------------------------------------");
//        $display("[GEN] Done  : all %0d transactions generated", count);
//        $display("----------------------------------------");
//    endtask

    // Coverage Code ================================================================
    bit seen[256];

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, event event_gen_next);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.event_gen_next = event_gen_next;
        for (int i = 0; i < 256; i++)
            seen[i] = 0;
    endfunction

    task run(int count = 256);
        $display("========================================");
        $display("[GEN] Start : total %0d transactions (full sweep 256)", count);
        $display("========================================");

        tr = new;
        repeat (256) begin
            transaction tr_copy;
            tr.randomize();
            tr.expect_data();
            seen[tr.tx_data] = 1;
            tr.debug_print("GEN");
            tr_copy         = new();
            tr_copy.tx_data = tr.tx_data;
            tr_copy.expect_U = tr.expect_U;
            tr_copy.expect_R = tr.expect_R;
            tr_copy.expect_D = tr.expect_D;
            tr_copy.expect_L = tr.expect_L;
            gen2drv_mbox.put(tr_copy);
            gen2scb_mbox.put(tr_copy);
            @(event_gen_next);
        end

        $display("----------------------------------------");
        $display("[GEN] Done : all 256 transactions generated");
        $display("----------------------------------------");
    endtask

    function void print_coverage();
        int covered       = 0;
        int ascii_cnt     = 0;  // 0x00~0x7F
        int non_ascii_cnt = 0;  // 0x80~0xFF
        int target_cnt    = 0;  // U,u / R,r / D,d / L,l

        // output target ascii list
        bit [7:0] target_list [8] = '{
            8'h55, 8'h75,  // U, u
            8'h52, 8'h72,  // R, r
            8'h44, 8'h64,  // D, d
            8'h4C, 8'h6C   // L, l
        };

        for (int i = 0; i < 256; i++)
            if (seen[i]) covered++;

        for (int i = 0; i < 128; i++)
            if (seen[i]) ascii_cnt++;

        for (int i = 128; i < 256; i++)
            if (seen[i]) non_ascii_cnt++;

        foreach (target_list[i])
            if (seen[target_list[i]]) target_cnt++;

        $display("========================================");
        $display("** Full Coverage  : %0d / 256 (%0.2f%%)  **",
                 covered, (covered / 256.0) * 100.0);
        $display("----------------------------------------");
        $display("** ASCII  (0x00~0x7F) : %0d / 128 (%0.2f%%)  **",
                 ascii_cnt, (ascii_cnt / 128.0) * 100.0);
        $display("** Non-ASCII (0x80~0xFF) : %0d / 128 (%0.2f%%)  **",
                 non_ascii_cnt, (non_ascii_cnt / 128.0) * 100.0);
        $display("----------------------------------------");
        $display("** Target (U,u/R,r/D,d/L,l) : %0d / 8  **", target_cnt);
        foreach (target_list[i]) begin
            $display("**   8'h%02h ('%s') : %s  **",
                     target_list[i],
                     string'(target_list[i]),
                     seen[target_list[i]] ? "TEST SUCCESS" : "TEST MISSING");
        end
        $display("========================================");
    endfunction

    // Coverage Code ================================================================
endclass

class driver;

    parameter BAUD_PERIOD_NS = (100_000_000 / 9600) * 10;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual top_interface top_vif;
    event event_gen_next;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual top_interface top_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.top_vif = top_vif;
    endfunction

    task preset();
        $display("----------------------------------------");
        $display("[DRV] Reset Assert   : rst = 1, rx = 1 (IDLE)");
        top_vif.rst = 1;
        top_vif.rx  = 1;
        repeat (2) @(posedge top_vif.clk);
        top_vif.rst = 0;
        $display("[DRV] Reset Deassert : rst = 0, DUT ready");
        $display("----------------------------------------");

        // assertion check rx_done
        @(negedge top_vif.clk);
        assert(!top_vif.dataU && !top_vif.dataR && !top_vif.dataD && !top_vif.dataL)
            $display("[DRV Assert] reset pass : all outputs = 0");
        else
            $display("[DRV Assert] reset fail : U=%0b R=%0b D=%0b L=%0b (expected all 0)",
                     top_vif.dataU, top_vif.dataR, top_vif.dataD, top_vif.dataL);
    endtask

    task send_data_print(string name);
        $display("%t : [%s] rx = %d", $time, name, top_vif.rx);
    endtask

    task send_byte(input bit [7:0] data);
        // drive timing control 
        @(posedge top_vif.clk);
        #1;

        // Start 
        top_vif.rx = 1'b0;
        #(BAUD_PERIOD_NS);

        // Data 
        for (int i = 0; i < 8; i++) begin
            top_vif.rx = data[i];
            send_data_print("DRV_SEND");
            #(BAUD_PERIOD_NS);
        end

        // Stop
        top_vif.rx = 1'b1;
        #(BAUD_PERIOD_NS);
    endtask

    task run();
        $display("----------------------------------------");
        $display("[DRV] Run start");
        $display("----------------------------------------");
        forever begin
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");
            // asynchronous rx timing control
            #(BAUD_PERIOD_NS * $urandom_range(1, 10));
            send_byte(tr.tx_data);
        end
    endtask

endclass

class monitor;
    parameter BAUD_PERIOD_NS = (100_000_000 / 9600) * 10;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual top_interface top_vif;
    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual top_interface top_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.top_vif = top_vif;
    endfunction

    task run();
        $display("----------------------------------------");
        $display("[MON] Monitor Active : waiting for rx_done");
        $display("----------------------------------------");
        forever begin
            tr = new;
            @(posedge top_vif.rx_done);
            repeat(2) @(posedge top_vif.clk);
            @(negedge top_vif.clk);
            tr.dataU = top_vif.dataU;
            tr.dataR = top_vif.dataR;
            tr.dataD = top_vif.dataD;
            tr.dataL = top_vif.dataL;
            $display("%t : [MON] Captured  dataU=%0b dataR=%0b dataD=%0b dataL=%0b",
                     $time, tr.dataU, tr.dataR,
                     tr.dataD, tr.dataL);
            mon2scb_mbox.put(tr);
            tr.debug_print("MON");
        end
    endtask

endclass

class scoreboard;

    transaction tr;
    transaction tr1;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event event_gen_next;

    function new(mailbox#(transaction) mon2scb_mbox,
                 mailbox#(transaction) gen2scb_mbox, event event_gen_next);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.event_gen_next = event_gen_next;
    endfunction

    int total_cnt = 0, pass_cnt = 0, fail_cnt = 0;
    int no_match_cnt = 0;

    task run();
        $display("----------------------------------------");
        $display("[SCB] Scoreboard Active");
        $display("----------------------------------------");
        forever begin
            mon2scb_mbox.get(tr);
            gen2scb_mbox.get(tr1);
            tr.debug_print("SCB");
            total_cnt++;

            if (!tr1.expect_U && !tr1.expect_R && !tr1.expect_D && !tr1.expect_L) begin
                no_match_cnt++;
                $display("%t : [SCB] #%0d  NO_MATCH | tx_data = 8'h%h ('%s') | all output = 0 (expected)",
                         $time, total_cnt, tr1.tx_data, string'(tr1.tx_data));
            end
            
            if ((tr.dataU == tr1.expect_U) &&
                (tr.dataR == tr1.expect_R) &&
                (tr.dataD == tr1.expect_D) &&
                (tr.dataL == tr1.expect_L)) begin
                pass_cnt++;
                $display("%t : [SCB] #%0d  PASS | tx_data = 8'h%h | dataU=%0b dataR=%0b dataD=%0b dataL=%0b",
                         $time, total_cnt, tr1.tx_data,
                         tr.dataU, tr.dataR,
                         tr.dataD, tr.dataL);
            end else begin
                fail_cnt++;
                $display("%t : [SCB] #%0d  FAIL | tx_data = 8'h%h",
                         $time, total_cnt, tr1.tx_data);
                $display("%t :        expected dataU=%0b dataR=%0b dataD=%0b dataL=%0b",
                         $time, tr1.expect_U, tr1.expect_R,
                         tr1.expect_D, tr1.expect_L);
                $display("%t :        received dataU=%0b dataR=%0b dataD=%0b dataL=%0b",
                         $time, tr.dataU, tr.dataR,
                         tr.dataD, tr.dataL);
            end
            -> event_gen_next;
        end
    endtask

    task print_summary();
        $display("");
        $display("========================================");
        $display("**   UART FIFO Decoder Verification   **");
        $display("========================================");
        $display("**  Total      : %4d                       **", total_cnt);
        $display("**  PASS       : %4d                       **", pass_cnt);
        $display("**  FAIL       : %4d                       **", fail_cnt);
        $display("**  NO_MATCH   : %4d (not U,u/R,r/D,d/L,l) **", no_match_cnt);
        $display("**  Result : %s        **",
                 (fail_cnt == 0) ? "*** ALL PASS ***" : "!!! FAIL EXIST !!!");
        $display("========================================");
        $display("");
    endtask

endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event event_gen_next;
    virtual top_interface top_vif;

    function new(virtual top_interface top_vif);
        this.top_vif = top_vif;
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen2scb_mbox = new;
        gen = new(gen2drv_mbox, gen2scb_mbox, event_gen_next);
        drv = new(gen2drv_mbox, top_vif);
        mon = new(mon2scb_mbox, top_vif);
        scb = new(mon2scb_mbox, gen2scb_mbox, event_gen_next);
    endfunction

    task run();
        $display("");
        $display("###########################################");
        $display("## UART FIFO Decoder Verification Start  ##");
        $display("###########################################");
        $display("");
        drv.preset();

        $display("[ENV] Fork Start : GEN / DRV / MON / SCB");
        fork
            gen.run(256);
            drv.run();
            mon.run();
            scb.run();
        join_any
        disable fork;

        $display("");
        $display("[ENV] Fork End : all tasks stopped");
 
        #20;
        scb.print_summary();
        gen.print_coverage();
 
        $display("###########################################");
        $display("##  UART FIFO Decoder Verification Done  ##");
        $display("###########################################");
        $display("");
 
        #20;
        $stop;
    endtask
endclass

 module tb_uart_fifo_decoder_sv ();
    top_interface top_if ();
    environment env;

    uart_fifo_decoder dut (
        .clk        (top_if.clk),
        .rst        (top_if.rst),
        .rx         (top_if.rx),
        .dataU(top_if.dataU),
        .dataR(top_if.dataR),
        .dataD(top_if.dataD),
        .dataL(top_if.dataL)
    );

    // assign inner signal for monitoring timing control
    assign top_if.rx_done = dut.w_rx_done;
    always #5 top_if.clk = ~top_if.clk;

    initial begin
        top_if.clk = 0;
        top_if.rx  = 1;
        env = new(top_if);
        env.run();
    end

endmodule
