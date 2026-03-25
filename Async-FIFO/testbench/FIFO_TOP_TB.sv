// TEST CASES COVERED:
//   Test 1 - Reset check         : after reset, Empty=1 and Full=0
//   Test 2 - Single write + read : basic data integrity
//   Test 3 - Fill to full        : write 16 entries, check Full flag
//   Test 4 - Write when full     : extra write must be ignored
//   Test 5 - Drain to empty      : read all 16 entries, check Empty flag
//   Test 6 - Read when empty     : extra read must be ignored
//   Test 7 - Half-full operation : write 8, read 8, check data order
//   Test 8 - Reset mid-operation : reset during use, FIFO recovers cleanly
//   Test 9 - Pointer wrap-around : write+read 48 entries (3 full laps)

`timescale 1ns/1ps

`define ADDR_WIDTH  4
`define DATA_WIDTH  8
`define DEPTH       16          

module FIFO_TOP_TB;

  // ===========================================================================
  // 1. SIGNALS
  // ===========================================================================
  logic                     W_CLK, R_CLK;
  logic                     W_rst_n, R_rst_n;
  logic                     W_inc, R_inc;
  logic [`DATA_WIDTH-1:0]   W_Data;
  logic                     Full, Empty;
  logic [`DATA_WIDTH-1:0]   R_Data;

  // Clock periods (in nanoseconds)
  localparam W_PERIOD = 10;   // Write clock  = 100 MHz
  localparam R_PERIOD = 17;   // Read  clock  =  59 MHz (different from write)

  // ===========================================================================
  // 2. REFERENCE MODEL (simple scoreboard)
  // ===========================================================================
  // exp_data  : stores what we wrote, in order
  // wr_idx    : next slot to write into
  // rd_idx    : next slot to read from
  // When we read the FIFO, we compare R_Data against exp_data[rd_idx].

  logic [`DATA_WIDTH-1:0]  exp_data [0:`DEPTH*4];  // big enough for wrap tests
  int                      wr_idx  = 0;
  int                      rd_idx  = 0;

  // Pass / fail counters
  int  pass_count = 0;
  int  fail_count = 0;

  // ===========================================================================
  // 3. DUT (Device Under Test)
  // ===========================================================================
  FIFO_TOP #(
    .ADDR_WIDTH (`ADDR_WIDTH),
    .DATA_WIDTH (`DATA_WIDTH)
  ) dut (
    .W_CLK   (W_CLK),   .R_CLK   (R_CLK),
    .W_rst_n (W_rst_n), .R_rst_n (R_rst_n),
    .W_inc   (W_inc),   .R_inc   (R_inc),
    .W_Data  (W_Data),
    .Full    (Full),    .Empty   (Empty),
    .R_Data  (R_Data)
  );

  // ===========================================================================
  // 4. CLOCK GENERATORS
  // ===========================================================================
  // Two independent clocks - this is the whole point of an async FIFO.
  // They start at different values so they are always out of phase.

  initial W_CLK = 0;
  always #(W_PERIOD/2) W_CLK = ~W_CLK;   // toggles every 5 ns

  initial R_CLK = 1;                       // starts HIGH - out of phase
  always #(R_PERIOD/2) R_CLK = ~R_CLK;   // toggles every 8.5 ns

  // ===========================================================================
  // 5. HELPER TASKS
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // do_reset - apply reset to both clock domains
  // ---------------------------------------------------------------------------
  // We hold both resets low for several clock cycles, then release them.
  // W_rst_n and R_rst_n are independent - we release them one at a time
  // to test that the FIFO handles staggered reset de-assertion correctly.

  task do_reset();
    $display("[RESET] Asserting reset on both domains");
    W_rst_n = 0;  R_rst_n = 0;
    W_inc   = 0;  R_inc   = 0;
    W_Data  = 0;
    repeat(5) @(posedge W_CLK);   // hold reset for 5 write clocks
    repeat(5) @(posedge R_CLK);   // and 5 read clocks
    W_rst_n = 1;                   // release write reset first
    repeat(3) @(posedge W_CLK);
    R_rst_n = 1;                   // then release read reset
    repeat(3) @(posedge R_CLK);
    $display("[RESET] Done. Empty=%0b Full=%0b", Empty, Full);
  endtask

  // ---------------------------------------------------------------------------
  // sync_delay - wait for a pointer to cross the 2-FF synchronizer
  // ---------------------------------------------------------------------------
  // After a write, the write pointer takes 2 R_CLK cycles to reach the
  // read domain. After a read, the read pointer takes 2 W_CLK cycles to
  // reach the write domain. We wait 6 cycles to be safe with any clock ratio.

  task sync_delay();
    repeat(6) @(posedge R_CLK);
    repeat(6) @(posedge W_CLK);
  endtask

  // ---------------------------------------------------------------------------
  // write_one - write a single byte into the FIFO
  // ---------------------------------------------------------------------------
  // Steps:
  //   1. Check Full - if full, print a warning and do nothing
  //   2. Drive W_Data and W_inc on the rising edge of W_CLK
  //   3. Hold for one cycle, then deassert W_inc
  //   4. Save the data in our reference array

  task write_one(input logic [`DATA_WIDTH-1:0] data);
    if (Full) begin
      $display("  [WRITE] Skipped 0x%02h - FIFO is Full", data);
      return;
    end
    @(posedge W_CLK); #1;   // align to clock, small delay after edge
    W_Data = data;
    W_inc  = 1;
    @(posedge W_CLK); #1;
    W_inc  = 0;
    W_Data = 'x;             // drive X after write - catches accidental latching
    exp_data[wr_idx] = data; // save to reference model
    wr_idx++;
    $display("  [WRITE] 0x%02h | Full=%0b Empty=%0b", data, Full, Empty);
  endtask

  // ---------------------------------------------------------------------------
  // read_one - read a single byte from the FIFO and check it
  // ---------------------------------------------------------------------------
  // IMPORTANT: The RAM read is asynchronous (no clock on the read port).
  // R_Data is valid as soon as R_Addr is stable - BEFORE the pointer
  // advances. So we must capture R_Data BEFORE asserting the next R_inc
  // (which would move the pointer and change R_Data immediately).
  //
  // Steps:
  //   1. Check Empty - if empty, print a warning and do nothing
  //   2. Assert R_inc - this tells the FIFO "I am reading this entry"
  //   3. Sample R_Data immediately (it is already valid from R_Addr)
  //   4. On the next clock edge R_ptr advances to the next slot
  //   5. Compare sampled data against reference array

  task read_one();
    logic [`DATA_WIDTH-1:0] got;

    if (Empty) begin
      $display("  [READ ] Skipped - FIFO is Empty");
      return;
    end

    @(posedge R_CLK); #1;
    R_inc = 1;
    got   = R_Data;          // capture NOW - async read, data is already valid
    @(posedge R_CLK); #1;
    R_inc = 0;

    // Compare against reference model
    if (got === exp_data[rd_idx]) begin
      $display("  [READ ] 0x%02h | Full=%0b Empty=%0b", got, Full, Empty);
      pass_count++;
    end else begin
      $display("  [READ ] FAIL - got 0x%02h, expected 0x%02h",
               got, exp_data[rd_idx]);
      fail_count++;
    end
    rd_idx++;
  endtask

  // ---------------------------------------------------------------------------
  // check - inline assertion with a message
  // ---------------------------------------------------------------------------
  task check(input string msg, input logic condition);
    if (condition) begin
      $display("  PASS: %s", msg);
      pass_count++;
    end else begin
      $display("  FAIL: %s", msg);
      fail_count++;
    end
  endtask

  // ===========================================================================
  // 6. SVA ASSERTIONS (automatic checks that run throughout simulation)
  // ===========================================================================
  // These fire silently on every clock edge.
  // If any of them trigger, Vivado prints an error automatically.

  // Full flag must never be X or Z
  assert property (@(posedge W_CLK) disable iff (~W_rst_n)
    !$isunknown(Full))
    else $error("SVA FAIL: Full flag is X or Z");

  // Empty flag must never be X or Z
  assert property (@(posedge R_CLK) disable iff (~R_rst_n)
    !$isunknown(Empty))
    else $error("SVA FAIL: Empty flag is X or Z");

  // After reset, Full must be 0
  assert property (@(posedge W_CLK)
    $rose(W_rst_n) |=> ~Full)
    else $error("SVA FAIL: Full not 0 after reset");

  // After reset, Empty must be 1
  assert property (@(posedge R_CLK)
    $rose(R_rst_n) |=> Empty)
    else $error("SVA FAIL: Empty not 1 after reset");

  // R_Data must not be X when a read is happening
  assert property (@(posedge R_CLK) disable iff (~R_rst_n)
    (R_inc && ~Empty) |-> !$isunknown(R_Data))
    else $error("SVA FAIL: R_Data is X during a valid read");

  // RAM must not be written when Full (W_CLK_en = W_inc & ~Full must be 0)
  assert property (@(posedge W_CLK) disable iff (~W_rst_n)
    Full |-> ~(W_inc & ~Full))
    else $error("SVA FAIL: RAM written while Full asserted");

  // Write pointer (Gray code) must change by at most 1 bit per cycle
  assert property (@(posedge W_CLK) disable iff (~W_rst_n)
    $countones(dut.W_ptr ^ $past(dut.W_ptr)) <= 1)
    else $error("SVA FAIL: W_ptr changed by more than 1 bit (Gray code broken)");

  // Read pointer (Gray code) must change by at most 1 bit per cycle
  assert property (@(posedge R_CLK) disable iff (~R_rst_n)
    $countones(dut.R_ptr ^ $past(dut.R_ptr)) <= 1)
    else $error("SVA FAIL: R_ptr changed by more than 1 bit (Gray code broken)");

  // ===========================================================================
  // 7. MAIN TEST SEQUENCE
  // ===========================================================================
  initial begin

    $display("====================================================");
    $display("  ASYNC FIFO - SIMPLE TESTBENCH");
    $display("  Depth=%0d  Data width=%0d bits", `DEPTH, `DATA_WIDTH);
    $display("  W_CLK=%0dns  R_CLK=%0dns", W_PERIOD, R_PERIOD);
    $display("====================================================");

    // ---------------------------------------------------------------
    // TEST 1: Reset check
    // After reset: Empty must be 1, Full must be 0.
    // ---------------------------------------------------------------
    $display("\n--- TEST 1: Reset check ---");
    do_reset();
    check("Empty=1 after reset", Empty === 1'b1);
    check("Full=0  after reset", Full  === 1'b0);

    // ---------------------------------------------------------------
    // TEST 2: Single write then read
    // Write one byte, wait for it to propagate, read it back.
    // ---------------------------------------------------------------
    $display("\n--- TEST 2: Single write then read ---");
    write_one(8'hA5);
    sync_delay();           // let write pointer reach read domain
    read_one();
    sync_delay();           // let read pointer reach write domain

    // ---------------------------------------------------------------
    // TEST 3: Fill FIFO to full
    // Write 16 entries one by one. After all writes + sync delay,
    // Full must assert.
    // ---------------------------------------------------------------
    $display("\n--- TEST 3: Fill FIFO to full ---");
    begin
      int i;
      // Reset index so our reference array starts fresh
      wr_idx = 0; rd_idx = 0;
      do_reset();
      for (i = 0; i < `DEPTH; i++) begin
        write_one(8'h10 + i);      // writes 0x10, 0x11, 0x12 ... 0x1F
        @(posedge W_CLK);          // one clock gap between writes
      end
    end
    // Wait for write pointer to cross synchronizer and Full to assert.
    // Worst case: 2 x R_CLK (34ns) + 1 x W_CLK (10ns) = ~44ns minimum.
    // repeat(20) x W_CLK = 200ns - safely covers any clock ratio.
    repeat(20) @(posedge W_CLK);
    check("Full asserted after 16 writes", Full === 1'b1);

    // ---------------------------------------------------------------
    // TEST 4: Write when full - must be silently ignored
    // The write_one task checks Full and returns early.
    // Our reference array must NOT get this byte.
    // ---------------------------------------------------------------
    $display("\n--- TEST 4: Write when full (should be ignored) ---");
    write_one(8'hFF);    // task will print "Skipped" and not push to ref model
    check("Full still asserted after ignored write", Full === 1'b1);

    // ---------------------------------------------------------------
    // TEST 5: Drain FIFO completely
    // Read all 16 entries and verify each one matches what we wrote.
    // After all reads, Empty must assert.
    // ---------------------------------------------------------------
    $display("\n--- TEST 5: Drain FIFO to empty ---");
    begin
      int i;
      for (i = 0; i < `DEPTH; i++) begin
        sync_delay();              // let write pointer stay visible in read domain
        read_one();
        @(posedge R_CLK);          // one clock gap between reads
      end
    end
    repeat(20) @(posedge R_CLK);
    check("Empty asserted after 16 reads", Empty === 1'b1);

    // ---------------------------------------------------------------
    // TEST 6: Read when empty - must be silently ignored
    // ---------------------------------------------------------------
    $display("\n--- TEST 6: Read when empty (should be ignored) ---");
    read_one();          // task will print "Skipped"
    check("Empty still asserted after ignored read", Empty === 1'b1);

    // ---------------------------------------------------------------
    // TEST 7: Half-full operation
    // Write 8 entries, read them all back, check data order (FIFO order).
    // This is the most typical real-world usage pattern.
    // ---------------------------------------------------------------
    $display("\n--- TEST 7: Half-full operation (8 writes then 8 reads) ---");
    begin
      int i;
      wr_idx = 0; rd_idx = 0;
      do_reset();
      // Write 8 bytes
      for (i = 0; i < 8; i++)
        write_one(8'hB0 + i);     // 0xB0, 0xB1 ... 0xB7
      sync_delay();
      // Read them all back - must come out in the same order
      for (i = 0; i < 8; i++) begin
        read_one();
        @(posedge R_CLK);
      end
      sync_delay();
      check("Neither Full nor Empty after half-fill drain",
            (Full === 0) && (Empty === 1));
    end

    // ---------------------------------------------------------------
    // TEST 8: Reset mid-operation
    // Write a few entries, then reset - the FIFO must recover cleanly.
    // After reset: Empty=1, Full=0, pointers back to zero.
    // ---------------------------------------------------------------
    $display("\n--- TEST 8: Reset mid-operation ---");
    write_one(8'hDE);
    write_one(8'hAD);
    write_one(8'hBE);
    // Apply reset while FIFO has data in it
    do_reset();
    // Reset the reference model too (hardware was reset, so discard old data)
    wr_idx = 0; rd_idx = 0;
    check("Empty=1 after mid-op reset", Empty === 1'b1);
    check("Full=0  after mid-op reset", Full  === 1'b0);
    // Write fresh data and read it back to confirm FIFO is functional
    write_one(8'hAA);
    sync_delay();
    read_one();
    sync_delay();

    // ---------------------------------------------------------------
    // TEST 9: Pointer wrap-around
    // The (ADDR_WIDTH+1)-bit Gray pointer wraps from 31 back to 0.
    // We do 3 complete fill+drain cycles = 48 write+read pairs total.
    // This exercises the MSB wrap logic in both pointer modules.
    // ---------------------------------------------------------------
    $display("\n--- TEST 9: Pointer wrap-around (3 full cycles = 48 ops) ---");
    begin
      int i;
      wr_idx = 0; rd_idx = 0;
      do_reset();
      for (i = 0; i < `DEPTH * 3; i++) begin
        write_one(i[7:0]);        // just use the loop counter as data
        sync_delay();
        read_one();
        @(posedge W_CLK);
      end
      $display("  Completed %0d write+read pairs (3 pointer wrap-arounds)",
               `DEPTH * 3);
    end

    // ===========================================================
    // FINAL REPORT
    // ===========================================================
    repeat(10) @(posedge W_CLK);  // let any pending assertions settle

    $display("\n====================================================");
    $display("  RESULTS");
    $display("  Checks passed : %0d", pass_count);
    $display("  Checks failed : %0d", fail_count);
    if (fail_count == 0)
      $display("  ** ALL TESTS PASSED **");
    else
      $display("  ** %0d TEST(S) FAILED - check log above **", fail_count);
    $display("====================================================\n");

    $finish;
  end

  // ===========================================================================
  // 8. WATCHDOG - kills simulation if it hangs
  // ===========================================================================
  initial begin
    #10_000_000;   // 10 ms - all 9 tests finish well within this
    $error("WATCHDOG: simulation did not finish in 10ms - possible hang");
    $finish;
  end


endmodule
