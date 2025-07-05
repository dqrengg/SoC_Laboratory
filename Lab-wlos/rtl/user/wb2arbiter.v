module wb2arbiter (
    // wb interface
    input         wb_clk_i,
    input         wb_rst_i,
    input         wbs_stb_i,
    input         wbs_cyc_i,
    input         wbs_we_i,
    input  [3:0]  wbs_sel_i,
    input  [31:0] wbs_dat_i,
    input  [31:0] wbs_adr_i,
    output        wbs_ack_o,
    output [31:0] wbs_dat_o,
    // arbiter interface
    output        cpu_req_valid,
    output [22:0] cpu_req_addr,
    output        cpu_req_rw,
    output [31:0] cpu_req_wdata,
    input         cpu_req_ack,
    input  [31:0] cpu_rsp_rdata
);
    wire valid;
    
    assign valid = wbs_stb_i & wbs_cyc_i;

    // wb to arbiter
    assign cpu_req_valid = valid;
    assign cpu_req_addr = wbs_adr_i[22:0]; // TODO: check addr width
    assign cpu_req_rw = wbs_we_i;
    assign cpu_req_wdata = wbs_dat_i;

    // arbiter to wb
    assign wbs_ack_o = cpu_req_ack;
    assign wbs_dat_o = cpu_rsp_rdata;

endmodule