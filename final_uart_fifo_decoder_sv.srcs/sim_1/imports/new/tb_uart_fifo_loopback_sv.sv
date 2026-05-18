`timescale 1ns / 1ps

class transaction;
    rand bit [7:0] tx_data;
    bit rx;
    bit tx;
    bit [7:0] compare_data;

    constraint char_set {
        tx_data inside {
        // char data 
            8'h55, 8'h75,  // U, u
            8'h52, 8'h72,  // R, r
            8'h44, 8'h64,  // D, d
            8'h4C, 8'h6C,  // L, l
            8'h41, 8'h42, 8'h43, 8'h45,  // A, B, C, E 
            8'h30, 8'h31, 8'h32  // 0, 1, 2 
        };
    }

    function debug_print(string name);
        $display("%t : [%s] tx_data = %h, rx = %d, tx = %d",
                 $time, name, tx_data, rx, tx);
    endfunction

endclass

interface loopback_interface ();
    logic clk;
    logic rst;
    logic rx;
    logic tx;
endinterface

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event event_gen_next;

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, 
                 event event_gen_next);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.event_gen_next = event_gen_next;
    endfunction

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
endclass

class driver;

    parameter BAUD_PERIOD_NS = (100_000_000 / 9600) * 10;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual loopback_interface loopback_vif;
    event event_gen_next;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual loopback_interface loopback_vif,
                 event event_gen_next);
        this.gen2drv_mbox = gen2drv_mbox;
        this.loopback_vif = loopback_vif;
        this.event_gen_next = event_gen_next;
    endfunction

    task preset();
        $display("----------------------------------------");
        $display("[DRV] Reset Assert   : rst = 1, rx = 1 (IDLE)");
        loopback_vif.rst = 1;
        loopback_vif.rx  = 1;
        repeat (2) @(posedge loopback_vif.clk);
        loopback_vif.rst = 0;
        $display("[DRV] Reset Deassert : rst = 0, DUT ready");
        $display("----------------------------------------");

        @(negedge loopback_vif.clk);

        assert(loopback_vif.rx === 1'b1)
            $display("[DRV Assert] reset pass : rx = 1 (IDLE)");
        else
            $display("[DRV Assert] reset fail : rx = %d (expected 1)", loopback_vif.rx);

        assert(loopback_vif.tx === 1'b1)
            $display("[DRV Assert] reset pass : tx = 1 (IDLE)");
        else
            $display("[DRV Assert] reset fail : tx = %d (expected 1)", loopback_vif.tx);
    endtask


    task send_data_print(string name);
        $display("%t : [%s] rx = %d", $time, name, loopback_vif.rx);
    endtask

    task send_byte(input bit [7:0] data);
    // drive timing control 
        @(posedge loopback_vif.clk);
        #1;
        $display("%t : [DRV] Frame Start  tx_data (PC) = 8'h%h ('%s')",
                 $time, data, string'(data));

        // Start 
        loopback_vif.rx = 1'b0;
        #(BAUD_PERIOD_NS);

        // Data 
        for (int i = 0; i < 8; i++) begin
            loopback_vif.rx = data[i];
            #(BAUD_PERIOD_NS);
            send_data_print("DRV_SEND");
        end

        // Stop
        loopback_vif.rx = 1'b1;
        #(BAUD_PERIOD_NS);
        $display("%t : [DRV] Frame Done   tx_data (PC) = 8'h%h", $time, data);
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
            -> event_gen_next;
        end
    endtask

endclass

class monitor;
    parameter BAUD_PERIOD_NS = (100_000_000 / 9600) * 10;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual loopback_interface loopback_vif;
    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual loopback_interface loopback_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.loopback_vif = loopback_vif;
    endfunction
    
    function send_data_print(string name);
        $display("%t : [%s] tx = %d", $time, name, loopback_vif.tx);
    endfunction 
    
    task run();
        $display("----------------------------------------");
        $display("[MON] Monitor Active : waiting for tx start bit (negedge tx)");
        $display("----------------------------------------");
        forever begin
            tr = new;
            @(negedge loopback_vif.tx);
            $display("%t : [MON] Start bit detected (tx = 0)", $time);
            // start wait
            #(BAUD_PERIOD_NS / 2);
            // data merge
            for (int i = 0; i < 8; i++) begin
                #(BAUD_PERIOD_NS);
                tr.compare_data[i] = loopback_vif.tx; 
                send_data_print("TX_SEND");
            end
            #(BAUD_PERIOD_NS);

            tr.tx       = loopback_vif.tx;
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

    function new(mailbox #(transaction) mon2scb_mbox,
                 mailbox #(transaction) gen2scb_mbox/*, event event_gen_next*/);
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
            if (tr1.tx_data == tr.compare_data) begin
                pass_cnt++;
                $display("%t : [SCB] #%0d  PASS | expected = 8'h%h | received = 8'h%h",
                         $time, total_cnt, tr1.tx_data, tr.compare_data);
            end 
            else begin
                fail_cnt++;
                $display("%t : [SCB] #%0d  FAIL | expected = 8'h%h | received = 8'h%h | tx = %d",
                         $time, total_cnt, tr1.tx_data, tr.compare_data, tr.tx);
            end
        end
    endtask

    task print_summary();
        $display("");
        $display("========================================");
        $display("**   UART Loopback Verification Report **");
        $display("========================================");
        $display("**  Total  : %4d                      **", total_cnt);
        $display("**  PASS   : %4d                      **", pass_cnt);
        $display("**  FAIL   : %4d                      **", fail_cnt);
        $display("**  Result : %s   **",
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
    mailbox #(transaction) gen2scb_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event event_gen_next;
    virtual loopback_interface loopback_vif;

    function new(virtual loopback_interface loopback_vif);
        this.loopback_vif = loopback_vif;
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen2scb_mbox = new;
        gen = new(gen2drv_mbox, gen2scb_mbox, event_gen_next);
        drv = new(gen2drv_mbox, loopback_vif, event_gen_next);
        mon = new(mon2scb_mbox, loopback_vif);
        scb = new(mon2scb_mbox, gen2scb_mbox);
    endfunction

    int run_count = 20;

    task run();
        $display("");
        $display("########################################");
        $display("##  UART Loopback Verification Start  ##");
        $display("########################################");
        $display("");

        drv.preset();
        $display("[ENV] Fork Start : GEN / DRV / MON / SCB");
        fork
            gen.run(run_count);
            drv.run();
            mon.run();
            scb.run();
        //join_any
        //disable fork;
        join_none
        wait (scb.total_cnt == run_count);
        $display("");
        $display("[ENV] Fork End : all tasks stopped");

        #20;
        scb.print_summary();
 
        $display("########################################");
        $display("##  UART Loopback Verification Done   ##");
        $display("########################################");
        $display("");
 
        #20;
        $stop;
    endtask
endclass


module tb_uart_fifo_loopback_sv();
    loopback_interface loopback_if ();
    environment env;

    uart_fifo_loopback dut (
        . clk (loopback_if.clk)  ,
        . rst (loopback_if.rst)  ,
        . rx  (loopback_if.rx )  ,
        . tx  (loopback_if.tx )  
    );
    always #5 loopback_if.clk = ~loopback_if.clk;

    initial begin
        loopback_if.clk = 0;
        loopback_if.rx = 1;
        env = new(loopback_if);
        env.run();
    end
endmodule

