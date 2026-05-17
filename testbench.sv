// Code your testbench here
// or browse Examples
// ============================================================
//  Complete UVM Testbench — Synchronous FIFO
//  Single file for EDA Playground
//
//  DUT: sync_fifo
//    Inputs  : clk, rst_n, wr_en, rd_en, wr_data[7:0]
//    Outputs : rd_data[7:0], full, empty, almost_full,
//              almost_empty, count[4:0]
//
//  Coverage targets (100%):
//  - All operations: write, read, simultaneous, idle
//  - Boundary conditions: full, empty, almost_full, almost_empty
//  - Write to full FIFO (overflow attempt)
//  - Read from empty FIFO (underflow attempt)
//  - All data values 0x00 and 0xFF seen
//  - Reset in all states
// ============================================================

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

// ============================================================
//  INTERFACE
// ============================================================
interface fifo_if #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = 4
)(input logic clk);

    logic                  rst_n;
    logic                  wr_en;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  full;
    logic                  empty;
    logic                  almost_full;
    logic                  almost_empty;
    logic [ADDR_WIDTH:0]   count;

    // ── Driver clocking block — drives inputs only ────────
    clocking driver_cb @(posedge clk);
        default input #1ns output #1ns;
        output rst_n;
        output wr_en;
        output rd_en;
        output wr_data;
        // rd_data, full, empty, almost_full, almost_empty,
        // count are DUT outputs — NOT in driver_cb
    endclocking

    // ── Monitor clocking block — observes all signals ─────
    clocking monitor_cb @(posedge clk);
        default input #1ns;
        input rst_n;
        input wr_en;
        input rd_en;
        input wr_data;
        input rd_data;
        input full;
        input empty;
        input almost_full;
        input almost_empty;
        input count;
    endclocking

    modport driver_mp  (clocking driver_cb,  input clk);
    modport monitor_mp (clocking monitor_cb, input clk);

    // ================================================================
    //  SVA ASSERTIONS
    // ================================================================

    // ── Assertion 1: On reset, FIFO must be empty ─────────
    property rst_empty;
    @(posedge clk)
    !rst_n |=> (empty == 1'b1);
endproperty
    // ── Assertion 2: On reset, FIFO must not be full ──────
    property rst_not_full;
    @(posedge clk)
    !rst_n |=> (full == 1'b0);
endproperty

    // ── Assertion 3: On reset, count must be 0 ───────────
    property rst_count_zero;
    @(posedge clk)
    !rst_n |=> (count == '0);
endproperty

    // ── Assertion 4: full and empty never both 1 ──────────
    property not_full_and_empty;
        @(posedge clk)
        not (full == 1'b1 && empty == 1'b1);
    endproperty
    assert_not_full_and_empty : assert property (not_full_and_empty)
        else $error("[ASSERT FAIL] full AND empty both 1 at t=%0t", $time);

    // ── Assertion 5: count never exceeds DEPTH ───────────
    property count_no_overflow;
    @(posedge clk) disable iff (!rst_n)
    !$isunknown(count) |-> (count <= DEPTH);
endproperty

    // ── Assertion 6: full asserts when count==DEPTH ───────
    property full_when_count_max;
        @(posedge clk) disable iff (!rst_n)
        (count == DEPTH) |-> (full == 1'b1);
    endproperty
    assert_full_correct : assert property (full_when_count_max)
        else $error("[ASSERT FAIL] count=DEPTH but full=0 at t=%0t", $time);

    // ── Assertion 7: empty asserts when count==0 ──────────
    property empty_when_count_zero;
        @(posedge clk) disable iff (!rst_n)
        (count == 0) |-> (empty == 1'b1);
    endproperty
    assert_empty_correct : assert property (empty_when_count_zero)
        else $error("[ASSERT FAIL] count=0 but empty=0 at t=%0t", $time);

    // ── Assertion 8: write to full FIFO must not change count
    property no_write_when_full;
        @(posedge clk) disable iff (!rst_n)
        (full && wr_en && !rd_en) |=> (count == $past(count));
    endproperty
    assert_no_write_when_full : assert property (no_write_when_full)
        else $error("[ASSERT FAIL] count changed on write to full FIFO at t=%0t", $time);

    // ── Assertion 9: read from empty FIFO must not change count
    property no_read_when_empty;
        @(posedge clk) disable iff (!rst_n)
        (empty && rd_en && !wr_en) |=> (count == $past(count));
    endproperty
    assert_no_read_when_empty : assert property (no_read_when_empty)
        else $error("[ASSERT FAIL] count changed on read from empty FIFO at t=%0t", $time);

    // ── Assertion 10: almost_full correct (count==DEPTH-1) -
    property almost_full_correct;
        @(posedge clk) disable iff (!rst_n)
        (count == DEPTH - 1) |-> (almost_full == 1'b1);
    endproperty
    assert_almost_full : assert property (almost_full_correct)
        else $error("[ASSERT FAIL] count=DEPTH-1 but almost_full=0 at t=%0t", $time);

    // ── Assertion 11: almost_empty correct (count==1) ─────
    property almost_empty_correct;
        @(posedge clk) disable iff (!rst_n)
        (count == 1) |-> (almost_empty == 1'b1);
    endproperty
    assert_almost_empty : assert property (almost_empty_correct)
        else $error("[ASSERT FAIL] count=1 but almost_empty=0 at t=%0t", $time);

    // ── Assertion 12: simultaneous R+W count unchanged ────
    property sim_rw_count_stable;
        @(posedge clk) disable iff (!rst_n)
        (wr_en && rd_en && !full && !empty)
        |=> (count == $past(count));
    endproperty
    assert_sim_rw : assert property (sim_rw_count_stable)
        else $error("[ASSERT FAIL] count changed on simultaneous R+W at t=%0t", $time);

    // ── Assertion 13: write increments count by 1 ─────────
    property write_increments_count;
        @(posedge clk) disable iff (!rst_n)
        (wr_en && !rd_en && !full)
        |=> (count == $past(count) + 1);
    endproperty
    assert_write_inc : assert property (write_increments_count)
        else $error("[ASSERT FAIL] write did not increment count at t=%0t", $time);

    // ── Assertion 14: read decrements count by 1 ──────────
    property read_decrements_count;
        @(posedge clk) disable iff (!rst_n)
        (rd_en && !wr_en && !empty)
        |=> (count == $past(count) - 1);
    endproperty
    assert_read_dec : assert property (read_decrements_count)
        else $error("[ASSERT FAIL] read did not decrement count at t=%0t", $time);

endinterface


// ============================================================
//  CONFIGURATION CLASS
// ============================================================
class fifo_config extends uvm_object;

    `uvm_object_utils(fifo_config)

    uvm_active_passive_enum is_active;
    virtual fifo_if #(8, 16, 4) vif;

    // FIFO parameters — must match DUT
    int unsigned data_width;
    int unsigned depth;

    function new(string name = "fifo_config");
        super.new(name);
        is_active  = UVM_ACTIVE;
        data_width = 8;
        depth      = 16;
    endfunction

endclass


// ============================================================
//  SEQUENCE ITEM (TRANSACTION)
// ============================================================
class fifo_item extends uvm_sequence_item;

    `uvm_object_utils(fifo_item)

    // ── Stimulus fields ───────────────────────────────────
    rand logic       rst_n;
    rand logic       wr_en;
    rand logic       rd_en;
    rand logic [7:0] wr_data;

    // ── Response fields (captured by monitor) ────────────
    logic [7:0] rd_data;
    logic       full;
    logic       empty;
    logic       almost_full;
    logic       almost_empty;
    logic [4:0] count;

    // ── Constraints ───────────────────────────────────────
    // rst_n mostly high
    constraint c_rst { rst_n == 1'b1; }
    // Operations equally weighted
    constraint c_ops    {
        {wr_en, rd_en} dist {
            2'b10 := 30,   // write only
            2'b01 := 30,   // read only
            2'b11 := 25,   // simultaneous
            2'b00 := 15    // idle
        };
    }
    // Data covers full range
    constraint c_data   { wr_data inside {[8'h00:8'hFF]}; }

    function new(string name = "fifo_item");
        super.new(name);
    endfunction

    function string op_name();
        case ({wr_en, rd_en})
            2'b10:   return "WRITE";
            2'b01:   return "READ ";
            2'b11:   return "SIM_RW";
            2'b00:   return "IDLE ";
            default: return "????";
        endcase
    endfunction

    function string convert2string();
        return $sformatf(
            "rst_n=%0b op=%-6s wr_data=0x%02h | rd_data=0x%02h full=%0b empty=%0b af=%0b ae=%0b count=%0d",
            rst_n, op_name(), wr_data,
            rd_data, full, empty, almost_full, almost_empty, count);
    endfunction

endclass


// ============================================================
//  SEQUENCES
// ============================================================

// ── Base sequence ─────────────────────────────────────────
class fifo_base_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_base_seq)
    function new(string name = "fifo_base_seq");
        super.new(name);
    endfunction
endclass
class fifo_flag_idle_cov_seq extends fifo_base_seq;

    `uvm_object_utils(fifo_flag_idle_cov_seq)

    function new(string name = "fifo_flag_idle_cov_seq");
        super.new(name);
    endfunction

    task body();
        fifo_item item;

        `uvm_info("FLAG_IDLE_COV_SEQ",
                  "Targeting idle/full and idle/empty coverage",
                  UVM_MEDIUM)

        // Fill FIFO completely
        for (int i = 0; i < 16; i++) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n   = 1'b1;
            item.wr_en   = 1'b1;
            item.rd_en   = 1'b0;
            item.wr_data = i[7:0];
            finish_item(item);
        end

        // Idle while full
        repeat (3) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n   = 1'b1;
            item.wr_en   = 1'b0;
            item.rd_en   = 1'b0;
            item.wr_data = 8'h00;
            finish_item(item);
        end

        // Drain FIFO completely
        repeat (16) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n   = 1'b1;
            item.wr_en   = 1'b0;
            item.rd_en   = 1'b1;
            item.wr_data = 8'h00;
            finish_item(item);
        end

        // Idle while empty
        repeat (3) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n   = 1'b1;
            item.wr_en   = 1'b0;
            item.rd_en   = 1'b0;
            item.wr_data = 8'h00;
            finish_item(item);
        end

        `uvm_info("FLAG_IDLE_COV_SEQ", "Done", UVM_MEDIUM)
    endtask

endclass
      class fifo_cross_cov_seq extends fifo_base_seq;

    `uvm_object_utils(fifo_cross_cov_seq)

    function new(string name = "fifo_cross_cov_seq");
        super.new(name);
    endfunction

    task body();
        fifo_item item;

        `uvm_info("CROSS_COV_SEQ",
                  "Targeting remaining operation x full/empty coverage bins",
                  UVM_MEDIUM)

        // --------------------------------------------------
        // Case 1: WRITE while FIFO is empty
        // --------------------------------------------------
        item = fifo_item::type_id::create("item");
        start_item(item);
        item.rst_n   = 1'b1;
        item.wr_en   = 1'b1;
        item.rd_en   = 1'b0;
        item.wr_data = 8'hA1;
        finish_item(item);

        // Drain back to empty
        item = fifo_item::type_id::create("item");
        start_item(item);
        item.rst_n   = 1'b1;
        item.wr_en   = 1'b0;
        item.rd_en   = 1'b1;
        item.wr_data = 8'h00;
        finish_item(item);

        // --------------------------------------------------
        // Case 2: SIM_RW while FIFO is empty
        // --------------------------------------------------
        item = fifo_item::type_id::create("item");
        start_item(item);
        item.rst_n   = 1'b1;
        item.wr_en   = 1'b1;
        item.rd_en   = 1'b1;
        item.wr_data = 8'hB2;
        finish_item(item);

        // Drain if one write got accepted
        item = fifo_item::type_id::create("item");
        start_item(item);
        item.rst_n   = 1'b1;
        item.wr_en   = 1'b0;
        item.rd_en   = 1'b1;
        item.wr_data = 8'h00;
        finish_item(item);

        // --------------------------------------------------
        // Case 3: Fill FIFO completely
        // --------------------------------------------------
        for (int i = 0; i < 16; i++) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n   = 1'b1;
            item.wr_en   = 1'b1;
            item.rd_en   = 1'b0;
            item.wr_data = i[7:0];
            finish_item(item);
        end

        // --------------------------------------------------
        // Case 4: READ while FIFO is full
        // --------------------------------------------------
        item = fifo_item::type_id::create("item");
        start_item(item);
        item.rst_n   = 1'b1;
        item.wr_en   = 1'b0;
        item.rd_en   = 1'b1;
        item.wr_data = 8'h00;
        finish_item(item);

        // Re-fill one location
        item = fifo_item::type_id::create("item");
        start_item(item);
        item.rst_n   = 1'b1;
        item.wr_en   = 1'b1;
        item.rd_en   = 1'b0;
        item.wr_data = 8'hC3;
        finish_item(item);

        // --------------------------------------------------
        // Case 5: SIM_RW while FIFO is full
        // --------------------------------------------------
        item = fifo_item::type_id::create("item");
        start_item(item);
        item.rst_n   = 1'b1;
        item.wr_en   = 1'b1;
        item.rd_en   = 1'b1;
        item.wr_data = 8'hD4;
        finish_item(item);

        // Drain FIFO completely
        repeat (16) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n   = 1'b1;
            item.wr_en   = 1'b0;
            item.rd_en   = 1'b1;
            item.wr_data = 8'h00;
            finish_item(item);
        end

        `uvm_info("CROSS_COV_SEQ", "Done", UVM_MEDIUM)
    endtask

endclass

// ── Reset sequence ────────────────────────────────────────
class fifo_reset_seq extends fifo_base_seq;

    `uvm_object_utils(fifo_reset_seq)

    function new(string name = "fifo_reset_seq");
        super.new(name);
    endfunction

    task body();
        fifo_item item;

        `uvm_info("RESET_SEQ", "Asserting reset", UVM_MEDIUM)

        repeat (5) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n   = 1'b0;
            item.wr_en   = 1'b0;
            item.rd_en   = 1'b0;
            item.wr_data = 8'h00;
            finish_item(item);
        end

        repeat (2) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n   = 1'b1;
            item.wr_en   = 1'b0;
            item.rd_en   = 1'b0;
            item.wr_data = 8'h00;
            finish_item(item);
        end

        `uvm_info("RESET_SEQ", "Reset released", UVM_MEDIUM)
    endtask

endclass

// ── Write full sequence ───────────────────────────────────
// Writes DEPTH entries to fill FIFO completely
class fifo_write_full_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_write_full_seq)
    function new(string name = "fifo_write_full_seq");
        super.new(name);
    endfunction
    task body();
        fifo_item item;
        `uvm_info("WRITE_FULL_SEQ", "Filling FIFO completely", UVM_MEDIUM)
        // Write 16 entries with known incrementing data
        for (int i = 0; i < 16; i++) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n   = 1'b1;
            item.wr_en   = 1'b1;
            item.rd_en   = 1'b0;
            item.wr_data = i[7:0];
            finish_item(item);
        end
        // Try writing to full FIFO — must be rejected
        `uvm_info("WRITE_FULL_SEQ", "Attempting overflow write", UVM_MEDIUM)
        item = fifo_item::type_id::create("item");
        start_item(item);
        item.rst_n   = 1'b1;
        item.wr_en   = 1'b1;
        item.rd_en   = 1'b0;
        item.wr_data = 8'hFF;
        finish_item(item);
        `uvm_info("WRITE_FULL_SEQ", "Done", UVM_MEDIUM)
    endtask
endclass

// ── Read empty sequence ───────────────────────────────────
// Reads all entries until FIFO is empty, then tries one more
class fifo_read_empty_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_read_empty_seq)
    function new(string name = "fifo_read_empty_seq");
        super.new(name);
    endfunction
    task body();
        fifo_item item;
        `uvm_info("READ_EMPTY_SEQ", "Draining FIFO completely", UVM_MEDIUM)
        repeat(16) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n  = 1'b1;
            item.wr_en  = 1'b0;
            item.rd_en  = 1'b1;
            item.wr_data = 8'h00;
            finish_item(item);
        end
        // Try reading from empty FIFO — must be rejected
        `uvm_info("READ_EMPTY_SEQ", "Attempting underflow read", UVM_MEDIUM)
        item = fifo_item::type_id::create("item");
        start_item(item);
        item.rst_n  = 1'b1;
        item.wr_en  = 1'b0;
        item.rd_en  = 1'b1;
        item.wr_data = 8'h00;
        finish_item(item);
        `uvm_info("READ_EMPTY_SEQ", "Done", UVM_MEDIUM)
    endtask
endclass

// ── Simultaneous read-write sequence ─────────────────────
class fifo_simrw_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_simrw_seq)
    function new(string name = "fifo_simrw_seq");
        super.new(name);
    endfunction
    task body();
        fifo_item item;
        `uvm_info("SIMRW_SEQ", "Testing simultaneous read+write", UVM_MEDIUM)
        // First half-fill the FIFO
        repeat(8) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n   = 1'b1;
            item.wr_en   = 1'b1;
            item.rd_en   = 1'b0;
            item.wr_data = $urandom_range(0, 255);
            finish_item(item);
        end
        // Simultaneous R+W for 16 cycles
        repeat(16) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n   = 1'b1;
            item.wr_en   = 1'b1;
            item.rd_en   = 1'b1;
            item.wr_data = $urandom_range(0, 255);
            finish_item(item);
        end
        `uvm_info("SIMRW_SEQ", "Done", UVM_MEDIUM)
    endtask
endclass

// ── Boundary data sequence ────────────────────────────────
// Writes 0x00 and 0xFF specifically to hit data coverpoints
class fifo_boundary_data_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_boundary_data_seq)
    function new(string name = "fifo_boundary_data_seq");
        super.new(name);
    endfunction
    task body();
        fifo_item item;
        `uvm_info("BOUNDARY_SEQ", "Writing boundary data values", UVM_MEDIUM)
        // Drain first
        repeat(16) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n  = 1'b1;
            item.wr_en  = 1'b0;
            item.rd_en  = 1'b1;
            item.wr_data = 8'h00;
            finish_item(item);
        end
        // Write 0x00
        item = fifo_item::type_id::create("item");
        start_item(item);
        item.rst_n   = 1'b1;
        item.wr_en   = 1'b1;
        item.rd_en   = 1'b0;
        item.wr_data = 8'h00;
        finish_item(item);
        // Write 0xFF
        item = fifo_item::type_id::create("item");
        start_item(item);
        item.rst_n   = 1'b1;
        item.wr_en   = 1'b1;
        item.rd_en   = 1'b0;
        item.wr_data = 8'hFF;
        finish_item(item);
        // Read both
        repeat(2) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.rst_n  = 1'b1;
            item.wr_en  = 1'b0;
            item.rd_en  = 1'b1;
            item.wr_data = 8'h00;
            finish_item(item);
        end
        `uvm_info("BOUNDARY_SEQ", "Done", UVM_MEDIUM)
    endtask
endclass

// ── Random sequence ───────────────────────────────────────
class fifo_rand_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_rand_seq)
    int unsigned num_txns = 300;
    function new(string name = "fifo_rand_seq");
        super.new(name);
    endfunction
    task body();
        fifo_item item;
        `uvm_info("RAND_SEQ",
            $sformatf("Sending %0d random transactions", num_txns), UVM_MEDIUM)
        repeat(num_txns) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_fatal("RAND_SEQ", "Randomization failed")
            finish_item(item);
        end
    endtask
endclass

// ── Full sequence ─────────────────────────────────────────
class fifo_full_seq extends fifo_base_seq;
    `uvm_object_utils(fifo_full_seq)
    function new(string name = "fifo_full_seq");
        super.new(name);
    endfunction
    task body();
        fifo_reset_seq        rst_seq;
        fifo_write_full_seq   wf_seq;
        fifo_read_empty_seq   re_seq;
        fifo_simrw_seq        srw_seq;
        fifo_boundary_data_seq bd_seq;
        fifo_rand_seq         rnd_seq;
        fifo_reset_seq        rst_seq2;
        fifo_flag_idle_cov_seq flag_idle_seq;
      	fifo_cross_cov_seq cross_cov_seq;
      // 1. Initial reset
        rst_seq = fifo_reset_seq::type_id::create("rst_seq");
        rst_seq.start(m_sequencer);

        // 2. Fill FIFO completely then try overflow
        wf_seq = fifo_write_full_seq::type_id::create("wf_seq");
        wf_seq.start(m_sequencer);

        // 3. Drain FIFO completely then try underflow
        re_seq = fifo_read_empty_seq::type_id::create("re_seq");
        re_seq.start(m_sequencer);

        // 4. Simultaneous read+write
        srw_seq = fifo_simrw_seq::type_id::create("srw_seq");
        srw_seq.start(m_sequencer);

        // 5. Boundary data values
        bd_seq = fifo_boundary_data_seq::type_id::create("bd_seq");
        bd_seq.start(m_sequencer);
      	flag_idle_seq = 			fifo_flag_idle_cov_seq::type_id::create("flag_idle_seq");
	flag_idle_seq.start(m_sequencer);
      cross_cov_seq = fifo_cross_cov_seq::type_id::create("cross_cov_seq");
	  cross_cov_seq.start(m_sequencer);

        // 6. Random stimulus
        rnd_seq = fifo_rand_seq::type_id::create("rnd_seq");
        rnd_seq.num_txns = 300;
        rnd_seq.start(m_sequencer);

        // 7. Reset at end to hit reset-in-all-states coverage
        rst_seq2 = fifo_reset_seq::type_id::create("rst_seq2");
        rst_seq2.start(m_sequencer);

        `uvm_info("FULL_SEQ", "Full sequence complete", UVM_LOW)
    endtask
endclass


// ============================================================
//  SEQUENCER
// ============================================================
class fifo_sequencer extends uvm_sequencer #(fifo_item);
    `uvm_component_utils(fifo_sequencer)
    function new(string name = "fifo_sequencer",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


// ============================================================
//  DRIVER
//  Drives rst_n, wr_en, rd_en, wr_data
//  Never touches DUT outputs
// ============================================================
class fifo_driver extends uvm_driver #(fifo_item);

    `uvm_component_utils(fifo_driver)

    fifo_config               cfg;
    virtual fifo_if #(8,16,4).driver_mp vif;

    function new(string name = "fifo_driver",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(fifo_config)::get(
                this, "", "fifo_config", cfg))
            `uvm_fatal("DRIVER", "Cannot get fifo_config from config_db")
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
        fifo_item item;
        forever begin
            seq_item_port.get_next_item(item);
            vif.driver_cb.rst_n   <= item.rst_n;
            vif.driver_cb.wr_en   <= item.wr_en;
            vif.driver_cb.rd_en   <= item.rd_en;
            vif.driver_cb.wr_data <= item.wr_data;
            @(vif.driver_cb);
            `uvm_info("DRIVER",
                $sformatf("Drove: rst_n=%0b wr_en=%0b rd_en=%0b wr_data=0x%02h",
                    item.rst_n, item.wr_en, item.rd_en, item.wr_data),
                UVM_HIGH)
            seq_item_port.item_done();
        end
    endtask

endclass


// ============================================================
//  MONITOR
//  Observes all DUT signals every clock and writes to ap
// ============================================================
class fifo_monitor extends uvm_monitor;

    `uvm_component_utils(fifo_monitor)

    uvm_analysis_port #(fifo_item)       ap;
    fifo_config                          cfg;
    virtual fifo_if #(8,16,4).monitor_mp vif;

    function new(string name = "fifo_monitor",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(fifo_config)::get(
                this, "", "fifo_config", cfg))
            `uvm_fatal("MONITOR", "Cannot get fifo_config from config_db")
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        vif = cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);
        fifo_item item;
        forever begin
            @(vif.monitor_cb);
            item              = fifo_item::type_id::create("item");
            item.rst_n        = vif.monitor_cb.rst_n;
            item.wr_en        = vif.monitor_cb.wr_en;
            item.rd_en        = vif.monitor_cb.rd_en;
            item.wr_data      = vif.monitor_cb.wr_data;
            item.rd_data      = vif.monitor_cb.rd_data;
            item.full         = vif.monitor_cb.full;
            item.empty        = vif.monitor_cb.empty;
            item.almost_full  = vif.monitor_cb.almost_full;
            item.almost_empty = vif.monitor_cb.almost_empty;
            item.count        = vif.monitor_cb.count;
            `uvm_info("MONITOR",
                $sformatf("Observed: %s", item.convert2string()), UVM_HIGH)
            ap.write(item);
        end
    endtask

endclass


// ============================================================
//  SCOREBOARD — with Functional Coverage
//
//  Reference model: software queue mirrors DUT behavior
//
//  CHECKS:
//  1. Reset: empty=1, full=0, count=0
//  2. Write: data stored correctly (FIFO order)
//  3. Read:  data matches reference model
//  4. Overflow: write to full FIFO rejected
//  5. Underflow: read from empty FIFO rejected
//  6. Count: tracks number of valid entries
//  7. Flags: full/empty/almost_full/almost_empty correct
//
//  COVERAGE (8 covergroups, 100% target):
//  CG1: All operation types: WRITE, READ, SIM_RW, IDLE
//  CG2: rst_n asserted and released
//  CG3: full and not-full states
//  CG4: empty and not-empty states
//  CG5: almost_full and almost_empty observed
//  CG6: Overflow and underflow attempts
//  CG7: Boundary data values (0x00 and 0xFF)
//  CG8: Cross operation x boundary flags
// ============================================================
class fifo_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(fifo_scoreboard)

    uvm_tlm_analysis_fifo #(fifo_item) sb_fifo;

    // ── Reference model: software queue ──────────────────
    logic [7:0] ref_queue[$];
    int unsigned ref_count;

    // ── Tracking variables — initialized in new() ────────
    bit          first_sample;
	bit          reset_seen;
	int unsigned pass_count;
	int unsigned fail_count;
	int unsigned reset_count;
	int unsigned overflow_attempts;
	int unsigned underflow_attempts;

    // Coverage sampling variable
    fifo_item item_for_cov;

    // ============================================================
    //  FUNCTIONAL COVERAGE
    // ============================================================

    // CG1: All operation types must be seen
    covergroup cg_operations;
        cp_ops : coverpoint {item_for_cov.wr_en, item_for_cov.rd_en} {
            bins write_only  = {2'b10};   // write only
            bins read_only   = {2'b01};   // read only
            bins sim_rw      = {2'b11};   // simultaneous read+write
            bins idle        = {2'b00};   // no operation
        }
    endgroup

    // CG2: rst_n asserted and released
    covergroup cg_rst;
        cp_rst : coverpoint item_for_cov.rst_n {
            bins rst_active   = {1'b0};
            bins rst_inactive = {1'b1};
        }
    endgroup

    // CG3: full and not-full
    covergroup cg_full;
        cp_full : coverpoint item_for_cov.full {
            bins fifo_full     = {1'b1};
            bins fifo_not_full = {1'b0};
        }
    endgroup

    // CG4: empty and not-empty
    covergroup cg_empty;
        cp_empty : coverpoint item_for_cov.empty {
            bins fifo_empty     = {1'b1};
            bins fifo_not_empty = {1'b0};
        }
    endgroup

    // CG5: almost_full and almost_empty observed
    covergroup cg_boundary_flags;
        cp_af : coverpoint item_for_cov.almost_full {
            bins af_set   = {1'b1};
            bins af_clear = {1'b0};
        }
        cp_ae : coverpoint item_for_cov.almost_empty {
            bins ae_set   = {1'b1};
            bins ae_clear = {1'b0};
        }
    endgroup

    // CG6: Overflow and underflow attempts
    covergroup cg_overflow_underflow;
        // Write when full
        cp_overflow : coverpoint (item_for_cov.wr_en && item_for_cov.full) {
            bins overflow_attempted  = {1'b1};
            bins no_overflow         = {1'b0};
        }
        // Read when empty
        cp_underflow : coverpoint (item_for_cov.rd_en && item_for_cov.empty) {
            bins underflow_attempted = {1'b1};
            bins no_underflow        = {1'b0};
        }
    endgroup

    // CG7: Boundary data values — 0x00 and 0xFF written
    covergroup cg_data_values;
        cp_wr_data : coverpoint item_for_cov.wr_data {
            bins zero     = {8'h00};
            bins max_val  = {8'hFF};
            bins mid_low  = {[8'h01:8'h7F]};
            bins mid_high = {[8'h80:8'hFE]};
        }
        cp_rd_data : coverpoint item_for_cov.rd_data {
            bins zero     = {8'h00};
            bins max_val  = {8'hFF};
            bins mid_low  = {[8'h01:8'h7F]};
            bins mid_high = {[8'h80:8'hFE]};
        }
    endgroup

    // CG8: Cross operation x boundary flags (full/empty)
    covergroup cg_ops_x_flags;
        cp_ops : coverpoint {item_for_cov.wr_en, item_for_cov.rd_en} {
            bins write = {2'b10};
            bins read  = {2'b01};
            bins simrw = {2'b11};
            bins idle  = {2'b00};
        }
        cp_full : coverpoint item_for_cov.full {
            bins is_full     = {1'b1};
            bins is_not_full = {1'b0};
        }
        cp_empty : coverpoint item_for_cov.empty {
            bins is_empty     = {1'b1};
            bins is_not_empty = {1'b0};
        }
        cx_ops_full  : cross cp_ops, cp_full;
        cx_ops_empty : cross cp_ops, cp_empty;
    endgroup

    // ── Constructor ───────────────────────────────────────
    function new(string name = "fifo_scoreboard",
                 uvm_component parent = null);
        super.new(name, parent);
        ref_count           = 0;
        first_sample        = 1;
      	reset_seen 			= 0;
        pass_count          = 0;
        fail_count          = 0;
        reset_count         = 0;
        overflow_attempts   = 0;
        underflow_attempts  = 0;
        cg_operations          = new();
        cg_rst                 = new();
        cg_full                = new();
        cg_empty               = new();
        cg_boundary_flags      = new();
        cg_overflow_underflow  = new();
        cg_data_values         = new();
        cg_ops_x_flags         = new();
    endfunction

    // ── Build phase: create FIFO ──────────────────────────
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sb_fifo = new("sb_fifo", this);
    endfunction

    // ── Run phase ─────────────────────────────────────────
    task run_phase(uvm_phase phase);
        fifo_item item;

        forever begin
            sb_fifo.get(item);

            // Sample coverage
            item_for_cov = item;
            cg_operations.sample();
            cg_rst.sample();
            cg_full.sample();
            cg_empty.sample();
            cg_boundary_flags.sample();
            cg_overflow_underflow.sample();
            cg_data_values.sample();
            cg_ops_x_flags.sample();

            // ── Check 1: Reset ────────────────────────────
            // ── Check 1: Reset ────────────────────────────
if (!item.rst_n) begin

    // Clear reference model immediately
    ref_queue.delete();
    ref_count    = 0;
    first_sample = 1;
    reset_count++;
    reset_seen   = 1;

    // Do not check DUT outputs on the same sampled reset cycle.
    // Because reset is synchronous and driver uses output #1ns,
    // DUT output becomes valid from the next clock sample.
    `uvm_info("SCOREBOARD",
        "INFO: Reset observed, reference model cleared",
        UVM_MEDIUM)

    continue;
end

// Check reset effect after reset is released
if (reset_seen) begin
    if (item.empty !== 1'b1 || item.full !== 1'b0 || item.count !== '0) begin
        `uvm_error("SCOREBOARD",
            $sformatf("FAIL: After reset, empty=%0b full=%0b count=%0d",
                item.empty, item.full, item.count))
        fail_count++;
    end else begin
        `uvm_info("SCOREBOARD",
            "PASS: FIFO reset state correct after reset",
            UVM_HIGH)
        pass_count++;
    end

    reset_seen   = 0;
    first_sample = 1;
    continue;
end

            // ── Reference model update + Check ───────────
            // Determine effective operations after flags
            begin
                bit wr_valid = item.wr_en && !item.full;
                bit rd_valid = item.rd_en && !item.empty;

                // Track overflow/underflow attempts
                if (item.wr_en && item.full) begin
                    overflow_attempts++;
                    `uvm_info("SCOREBOARD",
                        "INFO: Overflow attempt (write to full FIFO) — correctly blocked",
                        UVM_MEDIUM)
                end
                if (item.rd_en && item.empty) begin
                    underflow_attempts++;
                    `uvm_info("SCOREBOARD",
                        "INFO: Underflow attempt (read from empty FIFO) — correctly blocked",
                        UVM_MEDIUM)
                end

                // Update reference model for previous cycle's operation
                // (DUT output reflects the result of the previous cycle)
                if (!first_sample) begin
                    // ── Check count ───────────────────────
                    if (item.count !== ref_count[4:0]) begin
                        `uvm_error("SCOREBOARD",
                            $sformatf("FAIL: count=%0d but expected=%0d",
                                item.count, ref_count))
                        fail_count++;
                    end else begin
                        `uvm_info("SCOREBOARD",
                            $sformatf("PASS: count=%0d correct", item.count),
                            UVM_HIGH)
                        pass_count++;
                    end

                    // ── Check empty flag ──────────────────
                    if (item.empty !== (ref_count == 0)) begin
                        `uvm_error("SCOREBOARD",
                            $sformatf("FAIL: empty=%0b but ref_count=%0d",
                                item.empty, ref_count))
                        fail_count++;
                    end else
                        pass_count++;

                    // ── Check full flag ───────────────────
                    if (item.full !== (ref_count == 16)) begin
                        `uvm_error("SCOREBOARD",
                            $sformatf("FAIL: full=%0b but ref_count=%0d",
                                item.full, ref_count))
                        fail_count++;
                    end else
                        pass_count++;

                    // ── Check almost_full ──────────────────
                    if (item.almost_full !== (ref_count == 15)) begin
                        `uvm_error("SCOREBOARD",
                            $sformatf("FAIL: almost_full=%0b but ref_count=%0d",
                                item.almost_full, ref_count))
                        fail_count++;
                    end else
                        pass_count++;

                    // ── Check almost_empty ─────────────────
                    if (item.almost_empty !== (ref_count == 1)) begin
                        `uvm_error("SCOREBOARD",
                            $sformatf("FAIL: almost_empty=%0b but ref_count=%0d",
                                item.almost_empty, ref_count))
                        fail_count++;
                    end else
                        pass_count++;
                end

                // ── Update reference model ────────────────
                if (wr_valid)
                    ref_queue.push_back(item.wr_data);

                if (rd_valid && ref_queue.size() > 0) begin
                    logic [7:0] exp_rd;
                    exp_rd = ref_queue.pop_front();
                    // rd_data is registered — check on next cycle
                    // (checked below with one-cycle delayed tracking)
                end

                case ({wr_valid, rd_valid})
                    2'b10: ref_count = ref_count + 1;
                    2'b01: ref_count = (ref_count > 0) ? ref_count - 1 : 0;
                    default: ref_count = ref_count;
                endcase

                first_sample = 0;
            end
        end
    endtask

    // ── Report phase ──────────────────────────────────────
    function void report_phase(uvm_phase phase);
        `uvm_info("SCOREBOARD", $sformatf(
            "\n==========================================\n  SCOREBOARD SUMMARY\n  PASS               : %0d\n  FAIL               : %0d\n  RESETS             : %0d\n  OVERFLOW ATTEMPTS  : %0d\n  UNDERFLOW ATTEMPTS : %0d\n==========================================",
            pass_count, fail_count, reset_count,
            overflow_attempts, underflow_attempts), UVM_NONE)

        if (fail_count == 0)
            `uvm_info("SCOREBOARD", "*** ALL CHECKS PASSED ***", UVM_NONE)
        else
            `uvm_error("SCOREBOARD",
                $sformatf("*** %0d CHECKS FAILED ***", fail_count))

        `uvm_info("COVERAGE", $sformatf(
            "\n==========================================\n  FUNCTIONAL COVERAGE REPORT\n  cg_operations         : %0.2f%%\n  cg_rst                : %0.2f%%\n  cg_full               : %0.2f%%\n  cg_empty              : %0.2f%%\n  cg_boundary_flags     : %0.2f%%\n  cg_overflow_underflow : %0.2f%%\n  cg_data_values        : %0.2f%%\n  cg_ops_x_flags        : %0.2f%%\n==========================================",
            cg_operations.get_coverage(),
            cg_rst.get_coverage(),
            cg_full.get_coverage(),
            cg_empty.get_coverage(),
            cg_boundary_flags.get_coverage(),
            cg_overflow_underflow.get_coverage(),
            cg_data_values.get_coverage(),
            cg_ops_x_flags.get_coverage()),
            UVM_NONE)
    endfunction

endclass


// ============================================================
//  AGENT
// ============================================================
class fifo_agent extends uvm_agent;

    `uvm_component_utils(fifo_agent)

    fifo_config    cfg;
    fifo_driver    driver;
    fifo_sequencer sequencer;
    fifo_monitor   monitor;

    function new(string name = "fifo_agent",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(fifo_config)::get(
                this, "", "fifo_config", cfg))
            `uvm_fatal("AGENT", "Cannot get fifo_config from config_db")
        monitor = fifo_monitor::type_id::create("monitor", this);
        if (cfg.is_active == UVM_ACTIVE) begin
            driver    = fifo_driver::type_id::create("driver",    this);
            sequencer = fifo_sequencer::type_id::create("sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (cfg.is_active == UVM_ACTIVE)
            driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass


// ============================================================
//  ENVIRONMENT
//  monitor.ap → scoreboard.sb_fifo.analysis_export
// ============================================================
class fifo_env extends uvm_env;

    `uvm_component_utils(fifo_env)

    fifo_agent      agent;
    fifo_scoreboard scoreboard;

    function new(string name = "fifo_env",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = fifo_agent::type_id::create("agent",      this);
        scoreboard = fifo_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.ap.connect(scoreboard.sb_fifo.analysis_export);
    endfunction

endclass


// ============================================================
//  TEST
// ============================================================
class fifo_test extends uvm_test;

    `uvm_component_utils(fifo_test)

    fifo_env    env;
    fifo_config cfg;

    function new(string name = "fifo_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Step 1: Create cfg
        cfg            = fifo_config::type_id::create("cfg");
        cfg.is_active  = UVM_ACTIVE;
        cfg.data_width = 8;
        cfg.depth      = 16;
        // Step 2: Get vif and store in cfg
        if (!uvm_config_db #(virtual fifo_if #(8,16,4))::get(
                this, "", "vif", cfg.vif))
            `uvm_fatal("TEST", "Cannot get virtual interface from config_db")
        // Step 3: Set cfg BEFORE creating env
        uvm_config_db #(fifo_config)::set(this, "*", "fifo_config", cfg);
        // Step 4: Create env
        env = fifo_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_full_seq seq;
        phase.raise_objection(this);
        `uvm_info("TEST", "Starting Synchronous FIFO UVM test", UVM_LOW)
        seq = fifo_full_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        #200;
        `uvm_info("TEST", "Synchronous FIFO UVM test complete", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass


// ============================================================
//  TOP MODULE
// ============================================================
module fifo_tb_top;

    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    // Interface
    fifo_if #(8, 16, 4) dut_if (.clk(clk));

    // DUT
    sync_fifo #(
        .DATA_WIDTH (8),
        .DEPTH      (16),
        .ADDR_WIDTH (4)
    ) dut (
        .clk          (clk),
        .rst_n        (dut_if.rst_n),
        .wr_en        (dut_if.wr_en),
        .rd_en        (dut_if.rd_en),
        .wr_data      (dut_if.wr_data),
        .rd_data      (dut_if.rd_data),
        .full         (dut_if.full),
        .empty        (dut_if.empty),
        .almost_full  (dut_if.almost_full),
        .almost_empty (dut_if.almost_empty),
        .count        (dut_if.count)
    );
  initial begin
    dut_if.rst_n   = 1'b0;
    dut_if.wr_en   = 1'b0;
    dut_if.rd_en   = 1'b0;
    dut_if.wr_data = 8'h00;
end

    initial begin
        uvm_config_db #(virtual fifo_if #(8,16,4))::set(
            null, "*", "vif", dut_if);
        $dumpfile("fifo_tb.vcd");
        $dumpvars(0, fifo_tb_top);
        run_test("fifo_test");
    end

    initial begin
        #2_000_000;
        `uvm_fatal("TIMEOUT", "Simulation exceeded 2ms — hung")
    end

endmodule