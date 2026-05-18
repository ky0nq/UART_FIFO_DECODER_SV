`timescale 1ns / 1ps

class transaction;
    rand bit [7:0] tx_data;
//    randc bit [7:0] tx_data; // all case randomize
    bit rx;
    bit [7:0] rx_data;
    bit rx_done;

//    constraint char_set {
//        tx_data inside {
//        // char data 
//        8'h55, 8'h75,  // U, u
//        8'h52, 8'h72,  // R, r
//        8'h44, 8'h64,  // D, d
//        8'h4C, 8'h6C,  // L, l
//        8'h41, 8'h42, 8'h43, 8'h45,  // A, B, C, E 
//        8'h30, 8'h31, 8'h32  // 0, 1, 2 
//        };
//    }

    function debug_print(string name);
        $display(
            "%t : [%s] ascii_data = %h, rx = %d, rx_data = %h, rx_done = %d",
            $time, name, tx_data, rx, rx_data, rx_done);
    endfunction
endclass

interface rx_interface ();
    logic clk;
    logic rst;
    logic rx;
    logic [7:0] rx_data;
    logic rx_done;
endinterface

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event event_gen_next;

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, event event_gen_next);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.event_gen_next = event_gen_next;
    endfunction

    // random test
   task run(int count);
       $display("========================================");
       $display("[GEN] Start : total %0d transactions", count);
       $display("========================================");
       repeat (count) begin
           tr = new;
           tr.randomize();
           tr.debug_print("GEN");
           gen2drv_mbox.put(tr);
           gen2scb_mbox.put(tr);
           @(event_gen_next);
       end
       $display("----------------------------------------");
       $display("[GEN] Done  : all %0d transactions generated", count);
       $display("----------------------------------------");
   endtask

    // Coverage Code ================================================================
//    bit seen[256]; 
//
//    function new(mailbox#(transaction) gen2drv_mbox,
//                 mailbox#(transaction) gen2scb_mbox, event event_gen_next);
//        this.gen2drv_mbox   = gen2drv_mbox;
//        this.gen2scb_mbox   = gen2scb_mbox;
//        this.event_gen_next = event_gen_next;
//        foreach (seen[i]) seen[i] = 0;  
//    endfunction
//
//    task run(int count = 256);
//        tr = new;
//
//        $display("========================================");
//        $display("[GEN] Start : total %0d transactions (randc full sweep)", count);
//        $display("========================================");
//
//        repeat (count) begin
//            transaction tr_copy;
//            tr.randomize();
//            seen[tr.tx_data] = 1; 
//            tr.debug_print("GEN");
//            tr_copy = new();
//            tr_copy.tx_data = tr.tx_data;
//            gen2drv_mbox.put(tr_copy);
//            gen2scb_mbox.put(tr_copy);
//            @(event_gen_next);
//        end
//
//        $display("----------------------------------------");
//        $display("[GEN] Done  : all %0d transactions generated", count);
//        $display("----------------------------------------");
//    endtask
//
//    function void print_coverage();
//        int covered = 0;
//        foreach (seen[i]) if (seen[i]) covered++;
//        $display("========================================");
//        $display("** TX Data Coverage : %0d / 256 (%0.2f%%) **",
//                 covered, (covered / 256.0) * 100.0);
//        $display("========================================");
//    endfunction
    // Coverage Code ================================================================
endclass

//class driver;
//
//    parameter BAUD_PERIOD_NS = (100_000_000 / 9600) * 10;
//    transaction tr;
//    mailbox #(transaction) gen2drv_mbox;
//    virtual rx_interface rx_vif;
//    event event_gen_next;
//
//    function new(mailbox #(transaction) gen2drv_mbox,
//                 virtual rx_interface rx_vif);
//        this.gen2drv_mbox = gen2drv_mbox;
//        this.rx_vif = rx_vif;
//    endfunction
//
//    task preset();
//        $display("----------------------------------------");
//        $display("[DRV] Reset Assert   : rst = 1, rx = 1 (IDLE)");
//        rx_vif.rst = 1;
//        rx_vif.rx  = 1;
//        repeat (2) @(posedge rx_vif.clk);
//        rx_vif.rst = 0;
//        $display("[DRV] Reset Deassert : rst = 0, DUT ready");
//        $display("----------------------------------------");
//        @(negedge rx_vif.clk);
//
//        // assertion check rx_done
//        assert(!rx_vif.rx_done)
//            $display("[DRV Assert] reset pass : rx_done is Zero !");
//        else $display("[DRV Assert] reset fail : rx_done = %d", rx_vif.rx_done);
//    endtask
//
//    task send_data_print(string name);
//        $display("%t : [%s] rx = %d", $time, name, rx_vif.rx);
//    endtask
//
////    task send_byte(input bit [7:0] data);
////        // drive timing control 
////        @(posedge rx_vif.clk);
////        #1;
////        $display("%t : [DRV] Frame Start  tx_data (PC) = 8'h%h ('%s')",
////                 $time, data, string'(data));
////        // Start bit 
////        rx_vif.rx = 1'b0;
////        #(BAUD_PERIOD_NS);
////
////        // Data bits (8-bit)
////        for (int i = 0; i < 8; i++) begin
////            rx_vif.rx = data[i];
////            send_data_print("DRV_SEND");
////            #(BAUD_PERIOD_NS);
////        end
////
////        // Stop bit
////        rx_vif.rx = 1'b1;
////        #(BAUD_PERIOD_NS);
////        $display("%t : [DRV] Frame Done   tx_data (PC) = 8'h%h", $time, data);
////    endtask
//
//    // margin test =========================================================================
//    // +- 5%
//    task send_byte(input bit [7:0] data);
//        int jitter;
//
//        @(posedge rx_vif.clk);
//        #1;
//
//        // Start bit
//        rx_vif.rx = 1'b0;
//        jitter = $urandom_range(0, BAUD_PERIOD_NS / 10);
//        #(BAUD_PERIOD_NS - (BAUD_PERIOD_NS/20) + jitter);
//
//        // Data bits
//        for (int i = 0; i < 8; i++) begin
//            rx_vif.rx = data[i];
//            jitter = $urandom_range(0, BAUD_PERIOD_NS / 10); // 매 비트마다 다른 jitter
//            #(BAUD_PERIOD_NS - (BAUD_PERIOD_NS/20) + jitter);
//        end
//
//        // Stop bit
//        rx_vif.rx = 1'b1;
//        jitter = $urandom_range(0, BAUD_PERIOD_NS / 10);
//        #(BAUD_PERIOD_NS - (BAUD_PERIOD_NS/20) + jitter);
//    endtask
//
//    task run();
//        forever begin
//            gen2drv_mbox.get(tr);
//            tr.debug_print("DRV");
//            // asynchronous rx timing control
//            #(BAUD_PERIOD_NS * $urandom_range(1, 10));
//            send_byte(tr.tx_data);
//        end
//    endtask
//    // margin test =========================================================================
//
//endclass

// margin test class ==================================================
class driver;

    parameter BAUD_PERIOD_NS = (100_000_000 / 9600) * 10;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual rx_interface rx_vif;
    event event_gen_next;

    // ★ CHANGED: jitter 비율 외부 조절 가능
    real baud_error_ratio = 0.05; // 기본 ±5%

    function new(mailbox #(transaction) gen2drv_mbox,
                 virtual rx_interface rx_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.rx_vif = rx_vif;
    endfunction

    task preset();
        $display("----------------------------------------");
        $display("[DRV] Reset Assert   : rst = 1, rx = 1 (IDLE)");
        rx_vif.rst = 1;
        rx_vif.rx  = 1;
        repeat (2) @(posedge rx_vif.clk);
        rx_vif.rst = 0;
        $display("[DRV] Reset Deassert : rst = 0, DUT ready");
        $display("----------------------------------------");
        @(negedge rx_vif.clk);

        assert(!rx_vif.rx_done)
            $display("[DRV Assert] reset pass : rx_done is Zero !");
        else $display("[DRV Assert] reset fail : rx_done = %d", rx_vif.rx_done);
    endtask

    task send_data_print(string name);
        $display("%t : [%s] rx = %d", $time, name, rx_vif.rx);
    endtask

    task send_byte(input bit [7:0] data);
        int baud_error;
        int baud_error_max;

        baud_error_max = int'(BAUD_PERIOD_NS * baud_error_ratio * 2);

        @(posedge rx_vif.clk);
        #1;
        $display("%t : [DRV] Frame Start  tx_data = 8'h%h (baud error +-%0.0f%%)",
                 $time, data, baud_error_ratio * 100);

        // Start bit
        rx_vif.rx = 1'b0;
        baud_error = $urandom_range(0, baud_error_max);
        #(BAUD_PERIOD_NS - (baud_error_max/2) + baud_error);

        // Data bits
        for (int i = 0; i < 8; i++) begin
            rx_vif.rx = data[i];
            send_data_print("DRV_SEND");
            baud_error = $urandom_range(0, baud_error_max);
            #(BAUD_PERIOD_NS - (baud_error_max/2) + baud_error);
        end

        // Stop bit
        rx_vif.rx = 1'b1;
        baud_error = $urandom_range(0, baud_error_max);
        #(BAUD_PERIOD_NS - (baud_error_max/2) + baud_error);
        $display("%t : [DRV] Frame Done   tx_data = 8'h%h", $time, data);
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");
            #(BAUD_PERIOD_NS * $urandom_range(1, 10));
            send_byte(tr.tx_data);
        end
    endtask

endclass
// margin test class ==================================================

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual rx_interface rx_vif;
    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual rx_interface rx_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.rx_vif = rx_vif;
    endfunction

    task run();
        $display("----------------------------------------");
        $display("[MON] Monitor Active : waiting for rx_done");
        $display("----------------------------------------");
        forever begin
            tr = new;
            @(posedge rx_vif.rx_done); 
            @(negedge rx_vif.clk); 
            tr.rx      = rx_vif.rx;
            tr.rx_data = rx_vif.rx_data;
            tr.rx_done = rx_vif.rx_done;
            $display("%t : [MON] Captured  rx_data = 8'h%h, rx_done = %0b",
                     $time, tr.rx_data, tr.rx_done);
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
    bit [7:0] compare_data;

    function new(mailbox#(transaction) mon2scb_mbox,
                 mailbox#(transaction) gen2scb_mbox, event event_gen_next);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.event_gen_next = event_gen_next;
    endfunction

    int total_cnt = 0, pass_cnt = 0, fail_cnt = 0;

    task run();
        $display("----------------------------------------");
        $display("[SCB] Scoreboard Active");
        $display("----------------------------------------");
        forever begin
            mon2scb_mbox.get(tr);
            gen2scb_mbox.get(tr1);
            tr.debug_print("SCB");
            total_cnt++;
            if (tr1.tx_data == tr.rx_data) begin
                pass_cnt++;
                $display("%t : [SCB] #%0d  PASS | expected = 8'h%h | received = 8'h%h",
                         $time, total_cnt, tr1.tx_data, tr.rx_data);
            end else begin
                fail_cnt++;
                $display("%t : [SCB] #%0d  FAIL | expected = 8'h%h | received = 8'h%h | rx_done = %0b",
                         $time, total_cnt, tr1.tx_data, tr.rx_data, tr.rx_done);
            end
            ->event_gen_next;
        end
    endtask

    task print_summary();
        $display("");
        $display("========================================");
        $display("**      UART RX Verification Report   **");
        $display("========================================");
        $display("**  Total  : %4d                      **", total_cnt);
        $display("**  PASS   : %4d                      **", pass_cnt);
        $display("**  FAIL   : %4d                      **", fail_cnt);
        $display("**  Result : %s        **",
                 (fail_cnt == 0) ? "*** ALL PASS ***" : "!!! FAIL EXIST !!!");
        $display("========================================");
        $display("");
    endtask

    // margin test =========
    task reset_cnt();
        total_cnt = 0;
        pass_cnt  = 0;
        fail_cnt  = 0;
    endtask
    // margin test =========
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event event_gen_next;
    virtual rx_interface rx_vif;

    function new(virtual rx_interface rx_vif);
        this.rx_vif = rx_vif;
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen2scb_mbox = new;
        gen = new(gen2drv_mbox, gen2scb_mbox, event_gen_next);
        drv = new(gen2drv_mbox, rx_vif);
        mon = new(mon2scb_mbox, rx_vif);
        scb = new(mon2scb_mbox, gen2scb_mbox, event_gen_next);
    endfunction

//    task run();
//        $display("");
//        $display("########################################");
//        $display("##    UART RX Verification Start      ##");
//        $display("########################################");
//        $display("");
// 
//        // reset test by assertion
//        drv.preset();
//
//        $display("[ENV] Fork Start : GEN / DRV / MON / SCB");
//        fork
//            gen.run(50);
//            drv.run();
//            mon.run();
//            scb.run();
//        join_any
//        disable fork;
//
//        $display("");
//        $display("[ENV] Fork End : all tasks stopped");
//
//        #20;
//        
//        // Summary
//        scb.print_summary();
//        //gen.print_coverage();
// 
//        $display("########################################");
//        $display("##    UART RX Verification Done       ##");
//        $display("########################################");
//        $display("");
//        
//        #20;
//        $stop;
//    endtask
// margin test ==================================================
real baud_error_ratio_list[] = '{0.05, 0.10, 0.15, 0.20};
//                                ±5%   ±10%  ±15%  ±20%

parameter BAUD_PERIOD_NS = (100_000_000 / 9600) * 10;

task run();
    $display("");
    $display("########################################");
    $display("##    UART RX Verification Start      ##");
    $display("########################################");
    $display("");

    drv.preset();

    foreach (baud_error_ratio_list[i]) begin
        drv.baud_error_ratio = baud_error_ratio_list[i];

        $display("");
        $display("========================================");
        $display("[ENV] Baud Rate Error Test : +-%0.0f%%", baud_error_ratio_list[i] * 100.0);
        $display("========================================");

        fork
            gen.run(1000);
            drv.run();
            mon.run();
            scb.run();
        join_any
        disable fork;

        #(BAUD_PERIOD_NS * 20);

        scb.print_summary();
        scb.reset_cnt();

        begin
            transaction tmp;
            while (gen2drv_mbox.try_get(tmp));
            while (gen2scb_mbox.try_get(tmp));
            while (mon2scb_mbox.try_get(tmp));
        end

        $display("[ENV] Stage %0d done, next stage starting...", i+1);
        #100;
    end

    $display("");
    $display("########################################");
    $display("##    UART RX Verification Done       ##");
    $display("########################################");
    $display("");

    #20;
    $stop;
endtask
// margin test ==================================================
endclass


module tb_uartrx_sv ();
    rx_interface rx_if ();
    environment env;

    uartrx_sv dut (
        .clk    (rx_if.clk),
        .rst    (rx_if.rst),
        .rx     (rx_if.rx),
        .rx_data(rx_if.rx_data),
        .rx_done(rx_if.rx_done)
    );


    always #5 rx_if.clk = ~rx_if.clk;

    initial begin
        rx_if.clk = 0;
        env = new(rx_if);
        env.run();
    end
endmodule
