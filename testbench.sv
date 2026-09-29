`timescale 1ns/1ps

module tb;

    parameter DEPTH = 8;
    parameter WIDTH = 8;

    logic clk, rst;
    logic wr_en, rd_en;
    logic [WIDTH-1:0] data_in, data_out;
    logic full, empty;
    logic [$clog2(DEPTH+1)-1:0] count;

    fifo #(.DEPTH(DEPTH), .WIDTH(WIDTH)) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty),
        .count(count)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Fixed-size reference FIFO for the scoreboard
    logic [WIDTH-1:0] ref_mem [0:DEPTH-1];
    integer ref_head, ref_tail, ref_count;
    integer accepted_read, accepted_write;
    integer blocked_write, blocked_read;
    integer previous_count;
    integer errors;
    logic [WIDTH-1:0] expected_data;

    integer saw_write, saw_read, saw_full, saw_empty;

    // Compare the DUT with the reference FIFO after each clock edge
    always @(posedge clk) begin
        if (rst) begin
            ref_head = 0;
            ref_tail = 0;
            ref_count = 0;
        end
        else begin
            previous_count = count;
            accepted_read = rd_en && !empty;
            accepted_write = wr_en && !full;
            blocked_write = wr_en && full && !rd_en;
            blocked_read = rd_en && empty && !wr_en;

            if (wr_en) saw_write = 1;
            if (rd_en) saw_read = 1;
            if (full) saw_full = 1;
            if (empty) saw_empty = 1;

            // Save the oldest item before updating the reference FIFO
            if (accepted_read) begin
                if (ref_count == 0) begin
                    $display("ERROR: Scoreboard expected a read from an empty FIFO");
                    errors = errors + 1;
                end
                else begin
                    expected_data = ref_mem[ref_head];
                    ref_head = (ref_head + 1) % DEPTH;
                    ref_count = ref_count - 1;
                end
            end

            if (accepted_write) begin
                if (ref_count >= DEPTH) begin
                    $display("ERROR: Scoreboard expected a write to a full FIFO");
                    errors = errors + 1;
                end
                else begin
                    ref_mem[ref_tail] = data_in;
                    ref_tail = (ref_tail + 1) % DEPTH;
                    ref_count = ref_count + 1;
                end
            end

            // Wait for the DUT's nonblocking assignments to take effect
            #1;

            if (accepted_read) begin
                if (data_out !== expected_data) begin
                    $display("ERROR: DATA MISMATCH: expected=%h actual=%h",
                             expected_data, data_out);
                    errors = errors + 1;
                end
                else begin
                    $display("READ PASS: Data=%h", data_out);
                end
            end

            if (count !== ref_count) begin
                $display("ERROR: Count mismatch: expected=%0d actual=%0d",
                         ref_count, count);
                errors = errors + 1;
            end

            if (count > DEPTH) begin
                $display("ERROR: Count exceeded FIFO depth");
                errors = errors + 1;
            end

            if (blocked_write && count !== previous_count) begin
                $display("ERROR: FIFO count changed during blocked overflow write");
                errors = errors + 1;
            end

            if (blocked_read && count !== previous_count) begin
                $display("ERROR: FIFO count changed during blocked underflow read");
                errors = errors + 1;
            end
        end
    end

    task automatic write_data(input logic [WIDTH-1:0] data);
        begin
            @(negedge clk);
            wr_en = 1;
            rd_en = 0;
            data_in = data;

            @(negedge clk);
            wr_en = 0;
        end
    endtask

    task automatic read_data;
        begin
            @(negedge clk);
            wr_en = 0;
            rd_en = 1;

            @(negedge clk);
            rd_en = 0;
        end
    endtask

    task automatic simultaneous_rw(input logic [WIDTH-1:0] data);
        begin
            @(negedge clk);
            wr_en = 1;
            rd_en = 1;
            data_in = data;

            @(negedge clk);
            wr_en = 0;
            rd_en = 0;
        end
    endtask

    integer i;

    initial begin
        rst = 1;
        wr_en = 0;
        rd_en = 0;
        data_in = 0;

        ref_head = 0;
        ref_tail = 0;
        ref_count = 0;
        errors = 0;
        saw_write = 0;
        saw_read = 0;
        saw_full = 0;
        saw_empty = 0;

        $dumpfile("dump.vcd");
        $dumpvars(0, tb);

        $display("FIFO VERIFICATION STARTED");

        repeat (2) @(negedge clk);
        rst = 0;

        $display("TEST 1: Normal write/read");
        write_data(8'h24);
        write_data(8'h81);
        write_data(8'h09);
        write_data(8'h63);

        repeat (2) @(negedge clk);

        read_data();
        read_data();
        read_data();
        read_data();

        $display("TEST 2: Simultaneous read/write");
        write_data(8'hA1);
        write_data(8'hB2);
        simultaneous_rw(8'hC3);

        read_data();
        read_data();

        $display("TEST 3: Fill FIFO");
        for (i = 0; i < DEPTH; i = i + 1)
            write_data(8'h40 + i);

        repeat (2) @(negedge clk);

        if (full)
            $display("PASS: FIFO is full");
        else begin
            $display("ERROR: FIFO did not become full");
            errors = errors + 1;
        end

        $display("TEST 4: Overflow protection");
        @(negedge clk);
        wr_en = 1;
        rd_en = 0;
        data_in = 8'hEE;

        @(negedge clk);
        wr_en = 0;

        $display("TEST 5: Empty the FIFO");
        for (i = 0; i < DEPTH; i = i + 1)
            read_data();

        repeat (2) @(negedge clk);

        if (empty)
            $display("PASS: FIFO is empty");
        else begin
            $display("ERROR: FIFO did not become empty");
            errors = errors + 1;
        end

        $display("TEST 6: Underflow protection");
        @(negedge clk);
        wr_en = 0;
        rd_en = 1;

        @(negedge clk);
        rd_en = 0;

        repeat (2) @(negedge clk);

        $display("Final count = %0d", count);
        $display("Observed write=%0d read=%0d full=%0d empty=%0d",
                 saw_write, saw_read, saw_full, saw_empty);

        if (errors == 0)
            $display("RESULT: ALL CHECKS PASSED");
        else
            $display("RESULT: %0d CHECK(S) FAILED", errors);

        $display("FIFO VERIFICATION COMPLETED");
        $finish;
    end

endmodule