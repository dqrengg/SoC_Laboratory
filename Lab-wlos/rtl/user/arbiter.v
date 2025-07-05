module arbiter (
    input clk,
    input rst_n,
    // cpu-arbiter interface
    input         cpu_req_valid,
    input  [22:0] cpu_req_addr,
    input         cpu_req_rw,
    input  [31:0] cpu_req_wdata,
    output        cpu_req_ack,
    output [31:0] cpu_rsp_rdata,
    // dma-arbiter interface
    input         dma_req_valid,
    input  [22:0] dma_req_addr,
    input         dma_req_rw,
    input  [31:0] dma_req_wdata,
    output        dma_req_ack,
    output [31:0] dma_rsp_rdata,
    // arbiter-sdr controller interface
    output [22:0] user_addr,
    output        rw,
    output [31:0] data_in,
    input  [31:0] data_out,

    output        in_valid,
    input         out_valid,

    //output        in_id,
    //input         out_id,

    input  [3:0]  arb_busy,        // packed
    input  [3:0]  arb_row_opened,  // packed
    input  [51:0] arb_row_addr,    // packed
    input  [3:0]  arb_cache_valid, // packed
    input  [67:0] arb_cache_tag    // packed
);
    // unpacked input
    wire        bank_busy[0:3];
    wire        cache_valid[0:3];
    wire [16:0] cache_tag[0:3];
    wire [12:0] row_opened_addr[0:3];
    wire        row_opened_flag[0:3];

    assign { bank_busy[3], bank_busy[2], bank_busy[1], bank_busy[0] } = arb_busy;
    assign { cache_tag[3], cache_tag[2], cache_tag[1], cache_tag[0] } = arb_cache_tag;
    assign { cache_valid[3], cache_valid[2], cache_valid[1], cache_valid[0] } = arb_cache_valid;
    assign { row_opened_addr[3], row_opened_addr[2], row_opened_addr[1], row_opened_addr[0] } = arb_row_addr;
    assign { row_opened_flag[3], row_opened_flag[2], row_opened_flag[1], row_opened_flag[0] } = arb_row_opened;

    // Address Remap
    wire [12:0] cpu_RA, dma_RA;
    wire [1:0]  cpu_BA, dma_BA;
    wire [7:0]  cpu_CA, dma_CA;

    assign cpu_RA = { cpu_req_addr[22:15], cpu_req_addr[13:9] };
    assign cpu_BA = { cpu_req_addr[14],    cpu_req_addr[4]    };
    assign cpu_CA = { cpu_req_addr[8:5],   cpu_req_addr[3:0]  };
    assign dma_RA = { dma_req_addr[22:15], dma_req_addr[13:9] };
    assign dma_BA = { dma_req_addr[14],    dma_req_addr[4]    };
    assign dma_CA = { dma_req_addr[8:5],   dma_req_addr[3:0]  };

    wire cpu_tag, dma_tag;

    assign cpu_tag = { cpu_RA, cpu_CA[7:2] };
    assign dma_tag = { dma_RA, dma_CA[7:2] };

    wire cpu_bank_free, dma_bank_free;
    wire cpu_write_req, dma_write_req;
    wire cpu_cache_hit, dma_cache_hit;
    wire cpu_row_hit, dma_row_hit;
    wire cpu_row_precharged, dma_row_precharged;

    assign cpu_bank_free = ~bank_busy[cpu_BA];
    assign dma_bank_free = ~bank_busy[dma_BA];
    assign cpu_write_req = cpu_req_rw;
    assign dma_write_req = dma_req_rw;
    assign cpu_cache_hit = (cache_valid[cpu_BA] && cache_tag[cpu_BA] == cpu_tag);
    assign dma_cache_hit = (cache_valid[dma_BA] && cache_tag[dma_BA] == dma_tag);
    assign cpu_row_hit = (row_opened_flag[cpu_BA] && row_opened_addr[cpu_BA] == cpu_RA);
    assign dma_row_hit = (row_opened_flag[dma_BA] && row_opened_addr[dma_BA] == dma_RA);
    assign cpu_row_precharged = ~row_opened_flag[cpu_BA];
    assign dma_row_precharged = ~row_opened_flag[dma_BA];

    reg cpu_wait, dma_wait;
    wire cpu_acceptable, dma_acceptable;

    assign cpu_acceptable = cpu_req_valid & !cpu_wait & cpu_bank_free;
    assign dma_acceptable = dma_req_valid & !dma_wait & dma_bank_free;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_wait <= 1'b0;
            dma_wait <= 1'b0;
            in_valid_q <= 1'b0;
        end else begin
            if (cpu_acceptable || dma_acceptable) in_valid_q <= 1'b1;
            else in_valid_q <= 1'b0;

            if (dma_acceptable && cpu_acceptable) begin
                if (dma_write_req != cpu_write_req) begin
                    if (dma_write_req) dma_wait <= 1'b1;
                    else               cpu_wait <= 1'b1;
                end else if (dma_cache_hit != cpu_cache_hit) begin
                    if (dma_cache_hit) dma_wait <= 1'b1;
                    else               cpu_wait <= 1'b1;
                end else if (dma_row_hit != cpu_row_hit) begin
                    if (dma_row_hit) dma_wait <= 1'b1;
                    else             cpu_wait <= 1'b1;
                end else if (dma_row_precharged != cpu_row_precharged) begin
                    if (dma_row_precharged) dma_wait <= 1'b1;
                    else                    cpu_wait <= 1'b1;
                end else begin
                    dma_wait <= 1'b1;
                end
            end else if (dma_acceptable) begin
                dma_wait <= 1'b1;
            end else if (cpu_acceptable) begin
                cpu_wait <= 1'b1;
            end
            if (cpu_req_ack) cpu_wait <= 1'b0;
            if (dma_req_ack) dma_wait <= 1'b0;
        end
    end

    // reg [22:0] user_addr_q;
    // reg        rw_q;
    // reg [31:0] data_in_q;
    reg        in_valid_q;

    assign cpu_req_ack   = cpu_req_valid && (!cpu_req_rw && out_valid || cpu_req_rw && cpu_wait);
    assign cpu_rsp_rdata = data_out;
    assign dma_req_ack   = dma_req_valid && (!dma_req_rw && out_valid || dma_req_rw && dma_wait);
    assign dma_rsp_rdata = data_out;

    assign user_addr = dma_wait ? dma_req_addr : cpu_req_addr;
    assign rw        = dma_wait ? dma_req_rw : cpu_req_rw;
    assign data_in   = dma_wait ? dma_req_wdata : cpu_req_wdata;
    assign in_valid  = in_valid_q;

    // always @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) begin
    //         in_valid_q <= 1'b0;
    //     end else begin
    //         if (!busy) begin // pipeline version?
    //             if (dma_req_valid) begin
    //                 dma_req_ack_q <= dma_req_rw;
    //             end else if (cpu_req_valid) begin
    //                 cpu_req_ack_q <= dma_req_rw;
    //             end
    //         end
    //         if (cpu_req_ack_q) begin
    //             cpu_req_ack_q <= 1'b0;
    //         end
    //         if (dma_req_ack_q) begin
    //             dma_req_ack_q <= 1'b0;
    //         end
    //     end
    // end

endmodule