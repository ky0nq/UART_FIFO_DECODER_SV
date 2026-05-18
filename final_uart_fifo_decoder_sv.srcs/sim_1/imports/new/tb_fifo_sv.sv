`timescale 1ns / 1ps

class transaction;
    rand bit [7:0]  push_data;
    rand bit        push;
    rand bit        pop;
    bit [7:0]       pop_data;
    bit             full;
    bit             empty;
    // mode variable about push only , pop only, push.pop
    typedef enum int {PUSH_ONLY, POP_ONLY, RANDOM} mode_e; 
    mode_e          mode; // this variable is controlling by environment 
    // because driver <-> scoreboard not connection
    // or another method is event

    // do not use for sentence in constraint 
    // 16 push -> 16 pop -> push pop random scenario

    // push only constraint condition
//    constraint push_only {
//        push == 1;
//        pop  == 0;
//    }

    // this constraint is selection by mode information 
    constraint c_mode {
        if (mode == PUSH_ONLY) {
            push == 1;
            pop  == 0;
        } else if (mode == POP_ONLY) {
            push == 0;
            pop  == 1;
        }
        // else -> random test mode
    }

    function debug_print (string name);
        $display("%t : [%s] push_data = %d, push = %d, pop = %d, pop_data = %d, full = %d, empty = %d",
                $time, name, push_data, push, pop, pop_data, full, empty);
    endfunction
endclass

interface fifo_interface ();
    logic       clk;
    logic       rst;
    logic [7:0] push_data;
    logic       push;
    logic       pop;
    logic [7:0] pop_data;
    logic       full;
    logic       empty;
endinterface

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event event_gen_next;
    transaction::mode_e mode;

    function new(mailbox #(transaction) gen2drv_mbox, event event_gen_next);
        this.gen2drv_mbox = gen2drv_mbox;
        this.event_gen_next = event_gen_next;
    endfunction

    task run(int count);
        $display("========================================");
        $display("[GEN] Start : total %0d transactions", count);
        $display("========================================");
        repeat(count) begin
            tr = new;
            tr.mode = mode;
            tr.randomize();
            tr.debug_print("GEN");
            gen2drv_mbox.put(tr);
            @(event_gen_next);
        end
        $display("----------------------------------------");
        $display("[GEN] Done  : all %0d transactions generated", count);
        $display("----------------------------------------");
    endtask

endclass

class driver;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual fifo_interface fifo_vif;
    event event_gen_next;

    function new(mailbox #(transaction) gen2drv_mbox, event event_gen_next,
                virtual fifo_interface fifo_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.event_gen_next = event_gen_next;
        this.fifo_vif = fifo_vif;
    endfunction

    int push_only_try_cnt = 0;  // push = 1, pop = 0
    int pop_only_try_cnt  = 0;  // push = 0, pop = 1
    int push_pop_try_cnt  = 0;  // push = 1, pop = 1
    int no_op_try_cnt = 0;      // push = 0, pop = 0

    task preset();
        $display("----------------------------------------");
        $display("[DRV] Reset Assert   : rst = 1, push = 0, pop = 0");
        fifo_vif.rst = 1;
        fifo_vif.push_data = 0;
        fifo_vif.push = 0;
        fifo_vif.pop = 0;
        repeat (2) @(posedge fifo_vif.clk);
        fifo_vif.rst = 0;
        $display("[DRV] Reset Deassert : rst = 0, DUT ready");
        $display("----------------------------------------");

        @(negedge fifo_vif.clk);
        // assertion check full, empty
        assert(fifo_vif.empty)
            $display("[DRV Assert] reset pass : empty !");
        else $display("[DRV Assert] reset fail : empty = %d", fifo_vif.empty);
        assert(!fifo_vif.full)
            $display("[DRV Assert] reset pass : not full !");
        else $display("[DRV Assert] reset fail : full = %d", fifo_vif.full);
    endtask

    // push pop only test function ==============================================================================================
    function only_condition_debug_print(string name);
        $display("%t : [%s] push_data = %d, push = %d, pop = %d, pop_data = %d, full = %d, empty = %d",
                $time, name, fifo_vif.push_data, fifo_vif.push, fifo_vif.pop,
                fifo_vif.pop_data, fifo_vif.full, fifo_vif.empty);
    endfunction

    // full assertion test
    task push_only(int count);
    $display("fifo push only test");
        $display("----------------------------------------");
        $display("[DRV] push_only start : count = %0d", count);
        $display("----------------------------------------");
        repeat(count) begin
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV_GEN RANDOM");
            only_condition_debug_print("DRV_PUSH ONLY");

            @(posedge fifo_vif.clk);
            #1;
            
            fifo_vif.push = 1;
            fifo_vif.push_data = tr.push_data;
            fifo_vif.pop = 0;
            -> event_gen_next;
        end
        $display("----------------------------------------");
        $display("[DRV] push_only done");
        $display("----------------------------------------");
    endtask

    // empty assertion test                
    task pop_only(int count);
    $display("fifo pop only test");
        $display("----------------------------------------");
        $display("[DRV] pop_only start : count = %0d", count);
        $display("----------------------------------------");
        repeat(count) begin
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV_GEN RANDOM");
            only_condition_debug_print("DRV_POP ONLY");

            @(posedge fifo_vif.clk);
            #1;
            
            fifo_vif.push = 0;
            fifo_vif.push_data = 0;
            fifo_vif.pop = 1;
            -> event_gen_next;
        end
        $display("----------------------------------------");
        $display("[DRV] pop_only done");
        $display("----------------------------------------");
    endtask
    // ========================================================================================================================

    // randomize test
    task run();
        $display("----------------------------------------");
        $display("[DRV] Random run start");
        $display("----------------------------------------");
        forever begin
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");
            
            @(posedge fifo_vif.clk);
            #1;
            
            fifo_vif.push_data = tr.push_data;
            fifo_vif.push = tr.push;
            fifo_vif.pop = tr.pop;

            // scenario capture
            push_pop_scenario_count();

            $display("%t : [DRV] drive | push = %0d, push_data = %0d, pop = %0d",
                     $time, tr.push, tr.push_data, tr.pop);
        end
    endtask

    // all case counting 
    task push_pop_scenario_count();
        if      ( tr.push && !tr.pop) push_only_try_cnt++;
        else if (!tr.push &&  tr.pop) pop_only_try_cnt++;
        else if ( tr.push &&  tr.pop) push_pop_try_cnt++;
        else                          no_op_try_cnt++;
    endtask

endclass

class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual fifo_interface fifo_vif;
    function new(mailbox #(transaction) mon2scb_mbox,
                virtual fifo_interface fifo_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.fifo_vif = fifo_vif;
    endfunction

    task run();
        $display("----------------------------------------");
        $display("[MON] Monitor Active : sampling on negedge clk");
        $display("----------------------------------------");
        forever begin
            tr = new;
            @(negedge fifo_vif.clk);
            tr.push_data        = fifo_vif.push_data;
            tr.push             = fifo_vif.push;
            tr.pop              = fifo_vif.pop;
            tr.pop_data         = fifo_vif.pop_data;
            tr.full             = fifo_vif.full ;
            tr.empty            = fifo_vif.empty;
            $display("%t : [MON] Captured  push = %0d, pop = %0d, push_data = %0d, pop_data = %0d, full = %0d, empty = %0d",
                     $time, tr.push, tr.pop, tr.push_data, tr.pop_data, tr.full, tr.empty);
            mon2scb_mbox.put(tr);
            tr.debug_print("MON");
        end
    endtask

endclass

class scoreboard;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event event_gen_next;
    bit [7:0] fifo_que[$:16]; // fifo_name[$:size]
    bit [7:0] compare_data;

    function new(mailbox #(transaction) mon2scb_mbox, event event_gen_next);
        this.mon2scb_mbox = mon2scb_mbox;
        this.event_gen_next = event_gen_next;
    endfunction

    int push_only_ok_cnt   = 0;  // push=1, pop=0, full=0  
    int push_only_fail_cnt = 0;  // push=1, pop=0, full=1  
    int pop_only_ok_cnt    = 0;  // push=0, pop=1, empty=0 
    int pop_only_fail_cnt  = 0;  // push=0, pop=1, empty=1 
    int push_pop_ok_cnt    = 0;  // push=1, pop=1
    int push_pop_push_fail_cnt = 0;  // full=1 → just pop 
    int push_pop_pop_fail_cnt  = 0;  // empty=1 → just push 
    int push_pop_fail_cnt = 0;   // push=1, pop=1, full=1, empty=1

    int total_cnt = 0, pass_cnt = 0, fail_cnt = 0;

    task run();
        $display("----------------------------------------");
        $display("[SCB] Scoreboard Active");
        $display("----------------------------------------");
        forever begin
            mon2scb_mbox.get(tr);
            tr.debug_print("SCB");

            casex ({tr.push, tr.pop, tr.full, tr.empty})
                4'b100x: push_only_ok_cnt++; 
                4'b101x: push_only_fail_cnt++;
                4'b01x0: pop_only_ok_cnt++; 
                4'b01x1: pop_only_fail_cnt++; 
                4'b1100: push_pop_ok_cnt++;
                4'b1110: push_pop_push_fail_cnt++;
                4'b1101: push_pop_pop_fail_cnt++;
                4'b1111: push_pop_fail_cnt++;
                default: $display("%t : [SCB] no operation (push=0, pop=0)", $time);
            endcase


            // two if = all case cover
            if (tr.push && (!tr.full)) begin  
                fifo_que.push_front(tr.push_data);
                $display("%t : [SCB] push  push_data = %0d → fifo_que size = %0d",
                     $time, tr.push_data, fifo_que.size());
            end 
            if (tr.pop && (!tr.empty)) begin
                // pass / fail decision
                total_cnt++;
                compare_data = fifo_que.pop_back();
                if (tr.pop_data == compare_data) begin
                    pass_cnt++;
                    $display("%t : [SCB] #%0d  PASS | expected = %0d | received = %0d",
                         $time, total_cnt, compare_data, tr.pop_data);
                end else begin
                    fail_cnt++;
                    $display("%t : [SCB] #%0d  FAIL | expected = %0d | received = %0d | full = %0d, empty = %0d",
                         $time, total_cnt, compare_data, tr.pop_data, tr.full, tr.empty);
                end
            end
            -> event_gen_next;
        end
    endtask

    task push_pop_summary(
        int push_only_try, int pop_only_try, int push_pop_try, int no_op_try_cnt
    );
        $display("");
        $display("========================================");
        $display("**         FIFO Count Summary         **");
        $display("========================================");
        $display("**  [PUSH only]  try     : %4d        **", push_only_try);
        $display("**  [PUSH only]  accepted: %4d        **", push_only_ok_cnt);
        $display("**  [PUSH only]  ignored : %4d (full) **", push_only_fail_cnt);
        $display("**  [POP  only]  try     : %4d        **", pop_only_try);
        $display("**  [POP  only]  accepted: %4d        **", pop_only_ok_cnt);
        $display("**  [POP  only]  ignored : %4d (empty)**", pop_only_fail_cnt);
        $display("**  [PUSH & POP] try     : %4d        **", push_pop_try);
        $display("**  [PUSH & POP] both ok : %4d        **", push_pop_ok_cnt);
        $display("**  [PUSH & POP] push ng : %4d (full) **", push_pop_push_fail_cnt);
        $display("**  [PUSH & POP] pop  ng : %4d (empty)**", push_pop_pop_fail_cnt);
        $display("**  [PUSH & POP] both ng : %4d        **", push_pop_fail_cnt);
        $display("**  [NO Operation]       : %4d        **", no_op_try_cnt);
        $display("========================================");
        $display("");
    endtask

    task print_summary();
        $display("");
        $display("========================================");
        $display("**      FIFO Verification Report      **");
        $display("========================================");
        $display("**  Total  :  %4d                   **", total_cnt);
        $display("**  PASS   :  %4d                   **", pass_cnt);
        $display("**  FAIL   :  %4d                   **", fail_cnt);
        $display("**  Result : %s      **",
                 (fail_cnt == 0) ? "*** ALL PASS ***" : "!!! FAIL EXIST !!!");
        $display("========================================");
        $display("");
    endtask

endclass

//// ===============================================================================
//// Assertion Environment Code ====================================================
//// ===============================================================================
//class environment;
//    generator gen;
//    driver drv;
//    monitor mon;
//    scoreboard scb;
//
//    mailbox #(transaction) gen2drv_mbox;
//    mailbox #(transaction) mon2scb_mbox;
//    event event_gen_next;
//    virtual fifo_interface fifo_vif;
//    
//    int run_count;
//
//    function new(virtual fifo_interface fifo_vif);
//        this.fifo_vif = fifo_vif;
//        gen2drv_mbox = new;
//        mon2scb_mbox = new;
//        gen = new(gen2drv_mbox, event_gen_next);
//        drv = new(gen2drv_mbox, event_gen_next, fifo_vif);
//        mon = new(mon2scb_mbox, fifo_vif);
//        scb = new(mon2scb_mbox, event_gen_next);
//    endfunction
//
//    task run();
//        $display("");
//        $display("########################################");
//        $display("##    FIFO Verification Start         ##");
//        $display("########################################");
//        $display("");
//
//        // reset test by assertion
//        drv.preset();
//
//        $display("");
//        $display("========================================");
//        $display("[ENV] Phase 1 : push_only test (full check)");
//        $display("========================================");
//        // push only test for full signal "1" =================================================
//        run_count = 16;
//        fork
//            // push_only constraint ---------
//            gen.run(run_count);
//            drv.run();
//            mon.run();
//            scb.run();
//        join_any
//        disable fork;
//        $display("[ENV push push_only test end]");
//        scb.push_pop_summary(
//            drv.push_only_try_cnt,
//            drv.pop_only_try_cnt,
//            drv.push_pop_try_cnt
//        );
////            // ------------------------------
////
////            // push_only task version -------
////             gen.run(run_count);
////             drv.push_only(run_count);
////         join
////            // ------------------------------
////        
//        // delay (not exist delay time -> full x) 
//        #10;
//        if (fifo_vif.full)
//            $display("PASS : push only test");
//        else 
//            $display("Fail : push only test");
//        // this is not use monitor, scoreboard -> we use assertion 
//        // scoreboard is good to 통계(statistics)  -> assertion is automically test by condition (is good)
//        // assertion is good to signal test 
//        // ====================================================================================
//
//        // push --> pop only test for empty signal "1" ========================================
////        run_count = 16;
////        fork
////            gen.run(run_count);
////            drv.push_only(run_count);
////        join
////        $display("[ENV push push_only test end]");
////        
////        #10;
////        if (fifo_vif.full)
////            $display("[ENV] PASS : full = 1 after %0d pushes", run_count);
////        else
////            $display("[ENV] FAIL : full = 0 after %0d pushes (expected 1)", run_count);
////
////        $display("");
////        $display("========================================");
////        $display("[ENV] Phase 2 : pop_only test (empty check)");
////        $display("========================================");
////
////        fork
////            gen.run(run_count);
////            drv.pop_only(run_count);
////        join
////        $display("[ENV pop pop_only test end]");
////        
////        // delay (not exist delay time -> empty x) 
////        #10;
////        
////        if (fifo_vif.empty)
////            $display("[ENV] PASS : empty = 1 after %0d pops", run_count);
////        else
////            $display("[ENV] FAIL : empty = 0 after %0d pops (expected 1)", run_count);
//        // ====================================================================================
//
//        // randomize test  ====================================================================
////        $display("");
////        $display("========================================");
//////        $display("[ENV] Phase 3 : random test start");
////        $display("[ENV] random test start");
////        $display("========================================");
////        fork
////            gen.run(10);
////            drv.run();
////            mon.run();
////            scb.run();
////        join_any
//
//        // mon, scb print safe
////        disable fork; 
////
////        $display("");
////        $display("[ENV] Fork End : all tasks stopped");
//
//
//        #20;
//        scb.print_summary();
////        scb.push_pop_summary(
////            drv.push_only_try_cnt,
////            drv.pop_only_try_cnt,
////            drv.push_pop_try_cnt
////        );
//
//        $display("########################################");
//        $display("##    FIFO Verification Done          ##");
//        $display("########################################");
//        $display("");
//
//        #20;
//        $stop;
//    endtask
//endclass
//// ===============================================================================
//// ===============================================================================
//// ===============================================================================
// -> 
// ===============================================================================
// Test Mode Select Environment Code =============================================
// ===============================================================================
class environment;
    generator gen;
    driver    drv;
    monitor   mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event event_gen_next;
    virtual fifo_interface fifo_vif;

    function new(virtual fifo_interface fifo_vif);
        this.fifo_vif = fifo_vif;
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, event_gen_next);
        drv = new(gen2drv_mbox, event_gen_next, fifo_vif);
        mon = new(mon2scb_mbox, fifo_vif);
        scb = new(mon2scb_mbox, event_gen_next);
    endfunction

    task run_phase(transaction::mode_e mode, int count);
        gen.mode = mode;
        fork
            gen.run(count);
            drv.run();
            mon.run();
            scb.run();
        join_any
        disable fork;
    endtask

    task run();
        $display("");
        $display("########################################");
        $display("##    FIFO Verification Start         ##");
        $display("########################################");
        $display("");

        drv.preset();

        // Phase 1 : push only (fill)
//        $display("[ENV] Phase 1 : push only (%0d)", 16);
//        run_phase(transaction::PUSH_ONLY, 16);
//        scb.push_pop_summary(
//            drv.push_only_try_cnt,
//            drv.pop_only_try_cnt,
//            drv.push_pop_try_cnt
//        );
//        #10;
//        assert(fifo_vif.full)
//            $display("[ENV] Phase 1 PASS : full = 1");
//        else
//            $display("[ENV] Phase 1 FAIL : full = 0");

        // Phase 2 : pop only (drain)
//        $display("[ENV] Phase 2 : pop only (%0d)", 16);
//        run_phase(transaction::POP_ONLY, 16);
//        scb.push_pop_summary(
//            drv.push_only_try_cnt,
//            drv.pop_only_try_cnt,
//            drv.push_pop_try_cnt
//        );
//        #10;
//        assert(fifo_vif.empty)
//            $display("[ENV] Phase 2 PASS : empty = 1");
//        else
//            $display("[ENV] Phase 2 FAIL : empty = 0");
//
//        // Phase 3 : random
        $display("[ENV] Phase 3 : random (100)");
        run_phase(transaction::RANDOM, 100);
        scb.push_pop_summary(
            drv.push_only_try_cnt,
            drv.pop_only_try_cnt,
            drv.push_pop_try_cnt,
            drv.no_op_try_cnt
        );

        #20;
        scb.print_summary();

        $display("");
        $display("########################################");
        $display("##    FIFO Verification Done          ##");
        $display("########################################");
        $display("");
        #20;
        $stop;
    endtask

endclass
// ===============================================================================
// ===============================================================================
// ===============================================================================

module tb_fifo_sv ();
    fifo_interface fifo_if();
    environment env;

    fifo_sv dut (
        .clk      (fifo_if.clk),
        .rst      (fifo_if.rst),
        .push_data(fifo_if.push_data),
        .push     (fifo_if.push),
        .pop      (fifo_if.pop),
        .pop_data (fifo_if.pop_data),
        .full     (fifo_if.full),
        .empty    (fifo_if.empty)
    );

    always #5 fifo_if.clk = ~fifo_if.clk;

    initial begin
        fifo_if.clk = 0;
        env = new(fifo_if);
        env.run();
    end
endmodule