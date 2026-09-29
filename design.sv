module fifo #(
    parameter DEPTH = 8,
    parameter WIDTH = 8,
    parameter PTR_WIDTH = $clog2(DEPTH),
    parameter COUNT_WIDTH = $clog2(DEPTH+1)
)(
    input logic clk, rst,
    input logic wr_en, rd_en,
    input logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out,
    output logic full, empty,
    output logic [COUNT_WIDTH-1:0] count
);

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic write_accept, read_accept;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    assign write_accept = wr_en && !full;
    assign read_accept  = rd_en && !empty;

    // FIFO operation
    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr   <= 0;
            rd_ptr   <= 0;
            count    <= 0;
            data_out <= 0;
        end
        else begin
            if (write_accept) begin
                mem[wr_ptr] <= data_in;

                if (wr_ptr == DEPTH-1)
                    wr_ptr <= 0;
                else
                    wr_ptr <= wr_ptr + 1'b1;
            end

            if (read_accept) begin
                data_out <= mem[rd_ptr];

                if (rd_ptr == DEPTH-1)
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1'b1;
            end

            // Update FIFO count
            case ({write_accept, read_accept})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule