`timescale 1ns / 1ps

class transaction;
    // rand bit [7:0] d_ascii_data;
    // rand bit dec_start;

    // all ascii data test -> not randomize
    bit [7:0] d_ascii_data;
    bit dec_start;

    bit dataU;  //8'h55  
    bit dataR;  //8'h52
    bit dataD;  //8'h44
    bit dataL;  //8'h4c
    bit expect_U;
    bit expect_D;
    bit expect_R;
    bit expect_L;

//    constraint char_set {
//        d_ascii_data inside {
//        // char data 
//        8'h55, 8'h75,  // U, u
//        8'h52, 8'h72,  // R, r
//        8'h44, 8'h64,  // D, d
//        8'h4C, 8'h6C  // L, l
////        8'h41, 8'h42, 8'h43, 8'h45,  // A, B, C, E 
////        8'h30, 8'h31, 8'h32  // 0, 1, 2 
//        };
//    }
//
//    constraint dec_start_c {
//        dec_start dist {
//            1 := 80,
//            0 := 20
//        };
//    }

    function debug_print(string name);
        $display(
            "%t : [%s] d_ascii_data = %h, dec_start = %d, dataU = %d, dataD = %d, dataR = %d, dataL = %d",
            $time, name, d_ascii_data, dec_start, dataU, dataD, dataR, dataL);
    endfunction

    function void expect_data();
        expect_U = (d_ascii_data == 8'h55 || d_ascii_data == 8'h75) ? 1'b1 : 1'b0;
        expect_R = (d_ascii_data == 8'h52 || d_ascii_data == 8'h72) ? 1'b1 : 1'b0;
        expect_D = (d_ascii_data == 8'h44 || d_ascii_data == 8'h64) ? 1'b1 : 1'b0;
        expect_L = (d_ascii_data == 8'h4C || d_ascii_data == 8'h6C) ? 1'b1 : 1'b0;
    endfunction

    function void print(string name);
        $display(
            "%t : [%s] char=8'h%02h ('%s') ; expect data : (U,u = %b R,r = %b D,d = %b L,l = %b) / data : (U,u = %b R,r = %b D,d = %b L,l = %b)",
            $time, name, d_ascii_data, d_ascii_data, expect_U, expect_R, expect_D, expect_L, 
            dataU, dataR, dataD, dataL);
    endfunction
endclass

interface decoder_interface ();
    logic       clk;
    logic       rst;
    logic [7:0] d_ascii_data;
    logic       dec_start;
    logic       dataU;  //8'h55  
    logic       dataR;  //8'h52
    logic       dataD;  //8'h44
    logic       dataL;  //8'h4c
endinterface

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event event_gen_next;

//    function new(mailbox#(transaction) gen2drv_mbox,
//                 event event_gen_next);
//        this.gen2drv_mbox   = gen2drv_mbox;
//        this.event_gen_next = event_gen_next;
//    endfunction
//
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
//            @(event_gen_next);
//        end
//        $display("----------------------------------------");
//        $display("[GEN] Done  : all %0d transactions generated", count);
//        $display("----------------------------------------");
//    endtask

    // Coverage Code ================================================================
    bit seen[2][128];

    function new(mailbox#(transaction) gen2drv_mbox,
                 event event_gen_next);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.event_gen_next = event_gen_next;
        // Initialize
        for (int i = 0; i < 2; i++)
            for (int j = 0; j < 128; j++)
                seen[i][j] = 0;
    endfunction

    task run(int count = 256);
        bit [7:0] ascii_list[128];
        bit [7:0] ascii_list2[128];

        for (int i = 0; i < 128; i++) begin
            ascii_list[i]  = i[7:0];
            ascii_list2[i] = i[7:0];
        end

        // randomize test
        ascii_list.shuffle();
        ascii_list2.shuffle();

        $display("========================================");
        $display("[GEN] Start : ASCII full sweep (0x00~0x7F) x 2 phase = 256 transactions");
        $display("========================================");

        // Phase 1 : dec_start=0, shuffled ASCII
        $display("[GEN] Phase 1 : dec_start=0, ASCII shuffled");
        foreach (ascii_list[i]) begin
            transaction tr_copy = new();
            tr_copy.d_ascii_data    = ascii_list[i];
            tr_copy.dec_start       = 0;
            seen[0][ascii_list[i]]  = 1;
            tr_copy.debug_print("GEN");
            gen2drv_mbox.put(tr_copy);
            @(event_gen_next);
        end

        // Phase 2 : dec_start=1, shuffled ASCII
        $display("[GEN] Phase 2 : dec_start=1, ASCII shuffled");
        foreach (ascii_list2[i]) begin
            transaction tr_copy = new();
            tr_copy.d_ascii_data    = ascii_list2[i];
            tr_copy.dec_start       = 1;
            seen[1][ascii_list2[i]] = 1;
            tr_copy.debug_print("GEN");
            gen2drv_mbox.put(tr_copy);
            @(event_gen_next);
        end

        $display("----------------------------------------");
        $display("[GEN] Done : all 256 transactions generated");
        $display("----------------------------------------");
    endtask
 
    function void print_coverage();
        int covered_start0 = 0;
        int covered_start1 = 0;

        for (int j = 0; j < 128; j++) begin
            if (seen[0][j]) covered_start0++;
            if (seen[1][j]) covered_start1++;
        end

        $display("========================================");
        $display("** Full  Coverage : %0d / 256 (%0.2f%%)  **",
                 covered_start0 + covered_start1,
                 ((covered_start0 + covered_start1) / 256.0) * 100.0);
        $display("** dec_start=0   : %0d / 128 (%0.2f%%)  **",
                 covered_start0, (covered_start0 / 128.0) * 100.0);
        $display("** dec_start=1   : %0d / 128 (%0.2f%%)  **",
                 covered_start1, (covered_start1 / 128.0) * 100.0);
        $display("========================================");
    endfunction

    // Coverage Code ================================================================

endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual decoder_interface dec_vif;
    event event_gen_next;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual decoder_interface dec_vif, event event_gen_next);
        this.gen2drv_mbox = gen2drv_mbox;
        this.dec_vif = dec_vif;
        this.event_gen_next = event_gen_next;
    endfunction

    task preset();
        $display("----------------------------------------");
        $display("[DRV] Reset Assert   : rst = 1, dec_start = 0, d_ascii_data = 0");
        dec_vif.rst = 1;
        dec_vif.dec_start = 0;
        dec_vif.d_ascii_data = 0;
        repeat (2) @(posedge dec_vif.clk);
        dec_vif.rst = 0;
        $display("[DRV] Reset Deassert : rst = 0, DUT ready");
        $display("----------------------------------------");

        @(negedge dec_vif.clk);
        assert(!dec_vif.dataU && !dec_vif.dataR && !dec_vif.dataD && !dec_vif.dataL)
            $display("[DRV Assert] reset pass : all outputs = 0");
        else
            $display("[DRV Assert] reset fail : U=%0b R=%0b D=%0b L=%0b (expected all 0)",
                     dec_vif.dataU, dec_vif.dataR, dec_vif.dataD, dec_vif.dataL);
    endtask

    int total_decstart_cnt = 0, decstart_zero_cnt = 0, decstart_high_cnt = 0;

    task run();
        $display("----------------------------------------");
        $display("[DRV] Run start");
        $display("----------------------------------------");
        forever begin
            gen2drv_mbox.get(tr);

            repeat ($urandom_range(1, 10)) @(posedge dec_vif.clk);
            //@(posedge dec_vif.clk);
            #1;
            dec_vif.d_ascii_data = tr.d_ascii_data;
            dec_vif.dec_start = tr.dec_start;
            total_decstart_cnt++;
            //tr.debug_print("DRV");
            $display("%t : [DRV] Drive  d_ascii_data = 8'h%h ('%s'), dec_start = %0d",
                     $time, tr.d_ascii_data, string'(tr.d_ascii_data), tr.dec_start);
            
            if (!tr.dec_start) begin
                decstart_zero_cnt++;
                $display("%t : [DRV] dec_start = 0 → skip decode, trigger event_gen_next", $time);
                -> event_gen_next;
            end
            else begin
                decstart_high_cnt++;
            end

            // 1 clock pulse
            @(posedge dec_vif.clk);
            #1;
            dec_vif.dec_start = 1'b0;  
        end
    endtask

    task summary();
        $display("========================================");
        $display("[DRV] ======= Driver Summary =======");
        $display("[DRV] Total dec_start Randomize Count : %0d", total_decstart_cnt);
        $display("[DRV] dec_start = 1 Case : Total %0d", decstart_high_cnt);
        $display("[DRV] dec_start = 0 Case : Total %0d", decstart_zero_cnt);
        $display("========================================");
    endtask


endclass

class monitor;
    parameter BAUD_PERIOD_NS = (100_000_000 / 9600) * 10;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual decoder_interface dec_vif;
    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual decoder_interface dec_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.dec_vif = dec_vif;
    endfunction

    task run();
        $display("----------------------------------------");
        $display("[MON] Monitor Active : waiting for dec_start");
        $display("----------------------------------------");
        forever begin
            tr = new;
            @(posedge dec_vif.dec_start);
            @(negedge dec_vif.clk);
            tr.d_ascii_data = dec_vif.d_ascii_data;
            tr.dec_start    = dec_vif.dec_start;

            $display("%t : [MON] dec_start detected  d_ascii_data = 8'h%h ('%s')",
                     $time, tr.d_ascii_data, string'(tr.d_ascii_data));

            @(negedge dec_vif.dec_start);
            @(negedge dec_vif.clk);
            tr.dataD  = dec_vif.dataD;
            tr.dataU  = dec_vif.dataU;
            tr.dataR  = dec_vif.dataR;
            tr.dataL  = dec_vif.dataL;
            tr.expect_data(); // for coverage test 
            
            $display("%t : [MON] Captured  dataU=%0b dataR=%0b dataD=%0b dataL=%0b",
                     $time, tr.dataU, tr.dataR, tr.dataD, tr.dataL);
            mon2scb_mbox.put(tr);
            //tr.debug_print("MON");
        end
    endtask

endclass

class scoreboard;

    transaction tr;
    transaction tr1;
    mailbox #(transaction) mon2scb_mbox;
    event event_gen_next;

    function new(mailbox#(transaction) mon2scb_mbox,
                event event_gen_next);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.event_gen_next = event_gen_next;
    endfunction

    int total_cnt = 0, pass_cnt = 0, fail_cnt = 0;
    int no_match_cnt = 0;

    typedef struct {
        int       idx;
        time      timestamp;
        bit [7:0] data;
    } no_match_entry_t;
    no_match_entry_t no_match_log[$];

    task run();
        $display("----------------------------------------");
        $display("[SCB] Scoreboard Active");
        $display("----------------------------------------");
        forever begin
            mon2scb_mbox.get(tr);
            tr.print("SCB");
            total_cnt++;

            if (!tr.expect_U && !tr.expect_R && !tr.expect_D && !tr.expect_L) begin
                no_match_cnt++;
                no_match_log.push_back('{
                    idx       : total_cnt,
                    timestamp : $time,
                    data      : tr.d_ascii_data
                });
                $display("%t : [SCB] #%0d  NO_MATCH | char = 8'h%h ('%s') | all output = 0 (expected)",
                         $time, total_cnt, tr.d_ascii_data, string'(tr.d_ascii_data));
            end

            if ((tr.dataU == tr.expect_U) &&
                (tr.dataR == tr.expect_R) &&
                (tr.dataD == tr.expect_D) &&
                (tr.dataL == tr.expect_L)) begin
                pass_cnt++;
                $display("%t : [SCB] #%0d  PASS | char = 8'h%h ('%s') | U=%0b R=%0b D=%0b L=%0b",
                         $time, total_cnt, tr.d_ascii_data, string'(tr.d_ascii_data),
                         tr.dataU, tr.dataR, tr.dataD, tr.dataL);
            end 
            else begin
                fail_cnt++;
                $display("%t : [SCB] #%0d  FAIL | char = 8'h%h ('%s')",
                         $time, total_cnt, tr.d_ascii_data, string'(tr.d_ascii_data));
                $display("%t :        expected dataU=%0b dataR=%0b dataD=%0b dataL=%0b",
                         $time, tr.expect_U, tr.expect_R, tr.expect_D, tr.expect_L);
                $display("%t :        received dataU=%0b dataR=%0b dataD=%0b dataL=%0b",
                         $time, tr.dataU, tr.dataR, tr.dataD, tr.dataL);
            end
            -> event_gen_next;
        end
    endtask

    task print_summary();
        $display("");
        $display("========================================");
        $display("**    ASCII Decoder Verification      **");
        $display("========================================");
        $display("**  Total      : %4d                       **", total_cnt);
        $display("**  PASS       : %4d                       **", pass_cnt);
        $display("**  FAIL       : %4d                       **", fail_cnt);
        $display("**  NO_MATCH   : %4d (not U,u/R,r/D,d/L,l) **", no_match_cnt);
        $display("**  Result     : %s             **",
                 (fail_cnt == 0) ? "*** ALL PASS ***" : "!!! FAIL EXIST !!!");
        $display("========================================");
        $display("");
    endtask

     task no_match_summary();
        $display("");
        $display("========================================");
        $display("**      NO_MATCH Data Summary         **");
        $display("========================================");
        $display("**  Total NO_MATCH : %4d              **", no_match_cnt);
        $display("----------------------------------------");
        foreach (no_match_log[i]) begin
            $display("**  #%0d | %0t ns | data = 8'h%h ('%s')",
                     no_match_log[i].idx,
                     no_match_log[i].timestamp,
                     no_match_log[i].data,
                     string'(no_match_log[i].data));
        end
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
    event event_gen_next;
    virtual decoder_interface dec_vif;

    function new(virtual decoder_interface dec_vif);
        this.dec_vif = dec_vif;
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, event_gen_next);
        drv = new(gen2drv_mbox, dec_vif, event_gen_next);
        mon = new(mon2scb_mbox, dec_vif);
        scb = new(mon2scb_mbox, event_gen_next);
    endfunction

    task run();
        $display("");
        $display("########################################");
        $display("##  ASCII Decoder Verification Start  ##");
        $display("########################################");
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
        drv.summary();
        scb.no_match_summary();
        gen.print_coverage();
 
        $display("########################################");
        $display("##  ASCII Decoder Verification Done   ##");
        $display("########################################");
        $display("");

        // =====================================================================================
        #20;
        $stop;
    endtask
endclass

module tb_ascii_decoder_sv ();
    decoder_interface dec_if ();
    environment env;

    ascii_decoder_sv dut (
        .clk         (dec_if.clk),
        .rst         (dec_if.rst),
        .d_ascii_data(dec_if.d_ascii_data),
        .dec_start   (dec_if.dec_start),
        .dataU (dec_if.dataU),
        .dataR (dec_if.dataR),
        .dataD (dec_if.dataD),
        .dataL (dec_if.dataL)
    );

    always #5 dec_if.clk = ~dec_if.clk;

    initial begin
        dec_if.clk = 0;
        env = new(dec_if);
        env.run();
    end
endmodule