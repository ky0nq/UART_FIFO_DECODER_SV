`timescale 1ns / 1ps

class transaction;
    rand bit tx_start;
//    rand bit [7:0] tx_data;
    randc bit [7:0] tx_data; // all case randomize
    bit tx;
    bit tx_busy;
    bit [7:0] compare_data;

//    constraint char_set {
//        tx_data inside {
//        // char data 
//            8'h55, 8'h75,  // U, u
//            8'h52, 8'h72,  // R, r
//            8'h44, 8'h64,  // D, d
//            8'h4C, 8'h6C,  // L, l
//            8'h41, 8'h42, 8'h43, 8'h45,  // A, B, C, E 
//            8'h30, 8'h31, 8'h32  // 0, 1, 2 
//        };
//    }

    // tx_start randomize distribute
//    constraint tx_start_c {
//    tx_start dist {1 := 80, 0 := 20};
//    }

    function debug_print(string name);
        $display("%t : [%s] tx_data = %h, tx_start = %d, tx = %h, tx_busy = %d",
                 $time, name, tx_data, tx_start, tx, tx_busy);
    endfunction

endclass

interface tx_interface ();
    logic       clk;
    logic       rst;
    logic       tx_start;
    logic [7:0] tx_data;
    logic       tx;
    logic       tx_busy;
endinterface

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event event_gen_next;

//    function new(mailbox#(transaction) gen2drv_mbox,
//                 mailbox#(transaction) gen2scb_mbox, 
//                 event event_gen_next);
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
//            tr.debug_print("GEN");
//            gen2drv_mbox.put(tr);
//            
//            // tx_start not enable -> not put in gen2scb mailbox
//            if (tr.tx_start) begin
//                gen2scb_mbox.put(tr);  
//            end
//            @(event_gen_next);
//        end
//        $display("----------------------------------------");
//        $display("[GEN] Done  : all %0d transactions generated", count);
//        $display("----------------------------------------");
//    endtask

    // Coverage Code ================================================================
    bit seen[2][256];

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox,
                 event event_gen_next);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.event_gen_next = event_gen_next;
        // Initialize
        for (int i = 0; i < 2; i++)
            for (int j = 0; j < 256; j++)
                seen[i][j] = 0;
    endfunction

    task run(int count = 512);
        $display("========================================");
        $display("[GEN] Start : total %0d transactions (full sweep 512)", count);
        $display("========================================");
 
        // Phase 1 : tx_start=0, tx_data 256
        $display("[GEN] Phase 1 : tx_start=0, tx_data full sweep");
        tr = new;
        repeat (256) begin
            transaction tr_copy;
            tr.randomize() with { tx_start == 0; };
            seen[tr.tx_start][tr.tx_data] = 1;
            tr.debug_print("GEN");
            tr_copy          = new();
            tr_copy.tx_data  = tr.tx_data;
            tr_copy.tx_start = tr.tx_start;
            gen2drv_mbox.put(tr_copy);
            @(event_gen_next);
        end
 
        // Phase 2 : tx_start=1, tx_data 256
        $display("[GEN] Phase 2 : tx_start=1, tx_data full sweep");
        tr = new;
        repeat (256) begin
            transaction tr_copy;
            tr.randomize() with { tx_start == 1; };
            seen[tr.tx_start][tr.tx_data] = 1;
            tr.debug_print("GEN");
            tr_copy          = new();
            tr_copy.tx_data  = tr.tx_data;
            tr_copy.tx_start = tr.tx_start;
            gen2drv_mbox.put(tr_copy);
            gen2scb_mbox.put(tr_copy);  // tx_start=1 -> gen2scb
            @(event_gen_next);
        end
 
        $display("----------------------------------------");
        $display("[GEN] Done  : all 512 transactions generated");
        $display("----------------------------------------");
    endtask
 
    function void print_coverage();
        int covered        = 0;
        int covered_start0 = 0;
        int covered_start1 = 0;
    
        for (int i = 0; i < 2;   i++)
            for (int j = 0; j < 256; j++)
                if (seen[i][j]) covered++;
    
        for (int j = 0; j < 256; j++)
            if (seen[0][j]) covered_start0++;
    
        for (int j = 0; j < 256; j++)
            if (seen[1][j]) covered_start1++;
    
        $display("========================================");
        $display("** Full  Coverage : %0d / 512 (%0.2f%%)  **",
                 covered, (covered / 512.0) * 100.0);
        $display("** tx_start=0    : %0d / 256 (%0.2f%%)  **",
                 covered_start0, (covered_start0 / 256.0) * 100.0);
        $display("** tx_start=1    : %0d / 256 (%0.2f%%)  **",
                 covered_start1, (covered_start1 / 256.0) * 100.0);
        $display("========================================");
    endfunction
    // Coverage Code ================================================================

endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual tx_interface tx_vif;
     event event_gen_next;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual tx_interface tx_vif,
                  event event_gen_next);
        this.gen2drv_mbox = gen2drv_mbox;
        this.tx_vif = tx_vif;
        this.event_gen_next = event_gen_next;
    endfunction

    task preset();
        $display("----------------------------------------");
        $display("[DRV] Reset Assert   : rst = 1, tx_start = 0 (IDLE), tx_data = 0");
        tx_vif.rst = 1;
        tx_vif.tx_start = 0;
        tx_vif.tx_data = 0;
        repeat (2) @(posedge tx_vif.clk);
        tx_vif.rst = 0;
        $display("[DRV] Reset Deassert : rst = 0, DUT ready");
        $display("----------------------------------------");
        @(negedge tx_vif.clk);

        // assertion check rx_done
        assert(tx_vif.tx)
            $display("[DRV Assert] reset pass : tx is High !");
        else $display("[DRV Assert] reset fail : tx = %d", tx_vif.tx);

        assert(!tx_vif.tx_busy)
            $display("[DRV Assert] reset pass : tx_busy is Low !");
        else $display("[DRV Assert] reset fail : tx_busy = %d", tx_vif.tx_busy);
    endtask

    int total_txstart_cnt = 0, txstart_zero_cnt = 0, txstart_high_cnt = 0;

    task summary();
        $display("========================================");
        $display("[DRV] ======= Driver Summary =======");
        $display("[DRV] Total tx_start Randomize Count : %0d", total_txstart_cnt);
        $display("[DRV] tx_start = 1 Case : Total %0d", txstart_high_cnt);
        $display("[DRV] tx_start = 0 Case : Total %0d", txstart_zero_cnt);
        $display("========================================");
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            // asynchronous tx timing control
            repeat ($urandom_range(1, 10)) @(posedge tx_vif.clk);
            // tx_busy low -> clock positive edge
            while (tx_vif.tx_busy) @(posedge tx_vif.clk);
            #1;
            tr.debug_print("DRV");
            tx_vif.tx_data  = tr.tx_data;
            tx_vif.tx_start = tr.tx_start;
            total_txstart_cnt++;

            if (!tr.tx_start) begin
                txstart_zero_cnt++;
                -> event_gen_next;
            end
            else begin
                txstart_high_cnt++;
            end

            // 1 clock pulse making 
            @(posedge tx_vif.clk);
            #1;
            tx_vif.tx_start = 1'b0;  
        end
    endtask

endclass

class monitor;
    parameter BAUD_PERIOD_NS = (100_000_000 / 9600) * 10;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual tx_interface tx_vif;
    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual tx_interface tx_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.tx_vif = tx_vif;
    endfunction
    
    function send_data_print(string name);
        $display("%t : [%s] tx = %d, tx_busy = %d", $time, name, tx_vif.tx, tx_vif.tx_busy);
    endfunction 
    
    task run();
        $display("----------------------------------------");
        $display("[MON] Monitor Active : waiting for tx start bit (negedge tx)");
        $display("----------------------------------------");
        forever begin
            tr = new;
            // start -> next negative edge clock 
            @(negedge tx_vif.tx);

            // start wait
            #(BAUD_PERIOD_NS / 2);
            // data merge
            for (int i = 0; i < 8; i++) begin
                #(BAUD_PERIOD_NS);
                send_data_print("TX_SEND");
                tr.compare_data[i] = tx_vif.tx; 
            end
            #(BAUD_PERIOD_NS);

            @(negedge tx_vif.tx_busy);
            $display("%t : [MON] tx_busy deasserted, Frame complete (compare_data = 8'h%h)",
                     $time, tr.compare_data);
        
            tr.tx_start = tx_vif.tx_start;
            tr.tx_data  = tx_vif.tx_data;
            tr.tx       = tx_vif.tx;
            tr.tx_busy  = tx_vif.tx_busy;

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
                 mailbox #(transaction) gen2scb_mbox, event event_gen_next);
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
                $display("%t : [SCB] #%0d  FAIL | expected = 8'h%h | received = 8'h%h | tx_busy = %0b",
                         $time, total_cnt, tr1.tx_data, tr.compare_data, tr.tx_busy);
            end
            -> event_gen_next;
        end
    endtask

    task print_summary();
        $display("");
        $display("========================================");
        $display("**      UART TX Verification Report   **");
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
    virtual tx_interface tx_vif;

    function new(virtual tx_interface tx_vif);
        this.tx_vif = tx_vif;
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen2scb_mbox = new;
        gen = new(gen2drv_mbox, gen2scb_mbox, event_gen_next);
        drv = new(gen2drv_mbox, tx_vif, event_gen_next);
        mon = new(mon2scb_mbox, tx_vif);
        scb = new(mon2scb_mbox, gen2scb_mbox, event_gen_next);
    endfunction

    task run();
        $display("");
        $display("########################################");
        $display("##    UART TX Verification Start      ##");
        $display("########################################");
        $display("");

        drv.preset();

        $display("[ENV] Fork Start : GEN / DRV / MON / SCB");
        fork
            gen.run(512);
            drv.run();
            mon.run();
            scb.run();
        join_any
        disable fork;

        $display("");
        $display("[ENV] Fork End : all tasks stopped");

        #20;
        scb.print_summary();
        drv.summary();
        gen.print_coverage();
        $display("");
 

        $display("########################################");
        $display("##    UART TX Verification Done       ##");
        $display("########################################");
        $display("");
 
        #20;
        $stop;
    endtask
endclass


module tb_uarttx_sv ();
    tx_interface tx_if ();
    environment env;

    uarttx_sv dut (
        .clk     (tx_if.clk),
        .rst     (tx_if.rst),
        .tx_start(tx_if.tx_start),
        .tx_data (tx_if.tx_data),
        .tx      (tx_if.tx),
        .tx_busy (tx_if.tx_busy)
    );

    always #5 tx_if.clk = ~tx_if.clk;

    initial begin
        tx_if.clk = 0;
        tx_if.tx_start = 0; 
        env = new(tx_if);
        env.run();
    end
endmodule
