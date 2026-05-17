// Code your design here
// ============================================================
//  Synchronous FIFO
//
//  Parameters:
//    DATA_WIDTH = 8  (data bus width in bits)
//    DEPTH      = 16 (number of entries)
//    ADDR_WIDTH = 4  (log2(DEPTH) = log2(16) = 4)
//
//  Ports:
//    clk      — clock
//    rst_n    — active-low synchronous reset
//    wr_en    — write enable (push data in)
//    rd_en    — read enable  (pop data out)
//    wr_data  — data to write
//    rd_data  — data read out
//    full     — FIFO is full  (cannot write)
//    empty    — FIFO is empty (cannot read)
//    almost_full  — only 1 slot remaining
//    almost_empty — only 1 entry remaining
//    count    — number of valid entries currently in FIFO
//
//  Behavior:
//    - Write when wr_en=1 and full=0
//    - Read  when rd_en=1 and empty=0
//    - Simultaneous read+write when not empty and not full
//      → count stays same, data flows through
//    - On reset: all pointers, count, memory cleared
// ============================================================
module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = 4    // must be log2(DEPTH)
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic                  rd_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  full,
    output logic                  empty,
    output logic                  almost_full,
    output logic                  almost_empty,
    output logic [ADDR_WIDTH:0]   count       // one extra bit to hold 0..DEPTH
);

    // ── Memory array ──────────────────────────────────────
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // ── Pointers ──────────────────────────────────────────
    logic [ADDR_WIDTH-1:0] wr_ptr;   // points to next write location
    logic [ADDR_WIDTH-1:0] rd_ptr;   // points to next read  location

    // ── Internal write/read enable (with guard flags) ─────
    wire wr_valid = wr_en && !full;
    wire rd_valid = rd_en && !empty;

    // ── Write port ────────────────────────────────────────
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_valid) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr      <= wr_ptr + 1;
        end
    end

    // ── Read port ─────────────────────────────────────────
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr  <= '0;
            rd_data <= '0;
        end else if (rd_valid) begin
            rd_data <= mem[rd_ptr];
            rd_ptr  <= rd_ptr + 1;
        end
    end

    // ── Count register ────────────────────────────────────
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            count <= '0;
        end else begin
            case ({wr_valid, rd_valid})
                2'b10:   count <= count + 1;  // write only
                2'b01:   count <= count - 1;  // read  only
                default: count <= count;       // idle or simultaneous
            endcase
        end
    end

    // ── Status flags (combinational) ─────────────────────
    assign full         = (count == DEPTH);
    assign empty        = (count == 0);
    assign almost_full  = (count == DEPTH - 1);
    assign almost_empty = (count == 1);

endmodule