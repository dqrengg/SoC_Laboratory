// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_project_wrapper
 *
 * This wrapper enumerates all of the pins available to the
 * user for the user project.
 *
 * An example user project is provided in this wrapper.  The
 * example should be removed and replaced with the actual
 * user project.
 *
 *-------------------------------------------------------------
 */

module user_project_wrapper #(
    parameter BITS = 32
) (
`ifdef USE_POWER_PINS
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // Analog (direct connection to GPIO pad---use with caution)
    // Note that analog I/O is not available on the 7 lowest-numbered
    // GPIO pads, and so the analog_io indexing is offset from the
    // GPIO indexing by 7 (also upper 2 GPIOs do not have analog_io).
    inout [`MPRJ_IO_PADS-10:0] analog_io,

    // Independent clock (on independent integer divider)
    input   user_clock2,

    // User maskable interrupt signals
    output [2:0] user_irq
);
    // decode
    wire        mem_cyc, dma_cyc;
    wire        mem_sel, dma_sel;
    wire        mem_ack, dma_ack;
    wire [31:0] mem_dat, dma_dat;

    // arbiter interface
    wire        cpu_req_valid;
    wire [22:0] cpu_req_addr;
    wire        cpu_req_rw;
    wire [31:0] cpu_req_wdata;
    wire        cpu_req_ack;
    wire [31:0] cpu_rsp_rdata;
    wire        dma_req_valid;
    wire [22:0] dma_req_addr;
    wire        dma_req_rw;
    wire [31:0] dma_req_wdata;
    wire        dma_req_ack;
    wire [31:0] dma_rsp_rdata;

    wire [3:0]  arb_busy;
    wire [3:0]  arb_row_opened;
    wire [51:0] arb_row_addr;
    wire [3:0]  arb_cache_valid;
    wire [67:0] arb_cache_tag;

    // AXI-Lite
    wire        awready;
    wire        wready;
    wire        awvalid;
    wire [11:0] awaddr;
    wire        wvalid;
    wire [31:0] wdata;
    wire        arready;
    wire        rready;
    wire        arvalid;
    wire [11:0] araddr;
    wire        rvalid;
    wire [31:0] rdata;
    // AXIS
    wire        ss_tvalid;
    wire [31:0] ss_tdata;
    wire        ss_tlast;
    wire        ss_tready;
    wire        sm_tready;
    wire        sm_tvalid;
    wire [31:0] sm_tdata;
    wire        sm_tlast;
    // Tap and data RAM
    wire [3:0]  tap_WE;
    wire        tap_EN;
    wire [31:0] tap_Di;
    wire [11:0] tap_A;
    wire [31:0] tap_Do;
    wire [3:0]  data_WE;
    wire        data_EN;
    wire [31:0] data_Di;
    wire [11:0] data_A;
    wire [31:0] data_Do;

    // DMA IRQ
    wire        dma_irq;

    // SDR controller interface
    wire [22:0] user_addr;
    wire        rw;
    wire [31:0] data_in;
    wire [31:0] data_out;
    wire        busy;
    wire        in_valid;
    wire        out_valid;

    // SDR interface
    wire        sdram_cle;
    wire        sdram_cs;
    wire        sdram_cas;
    wire        sdram_ras;
    wire        sdram_we;
    wire [3:0]  sdram_dqm;
    wire [1:0]  sdram_ba;
    wire [12:0] sdram_a;
    wire [31:0] sdram_dqi;
    wire [31:0] sdram_dqo;
    
    assign user_irq = { 2'b0, dma_irq };

    wb_decoder user_wb_dec (
        .mprj_cyc(wbs_cyc_i),
        .mprj_adr(wbs_adr_i),
        .mprj_ack(wbs_ack_o),
        .mprj_dat(wbs_dat_o),
        .dma_cyc(dma_cyc),
        .dma_ack(dma_ack),
        .dma_dat(dma_dat),
        .mem_cyc(mem_cyc),
        .mem_ack(mem_ack),
        .mem_dat(mem_dat)
    );

    wb2arbiter user_wb2arb (
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
        .wbs_stb_i(wbs_stb_i),
        .wbs_cyc_i(mem_cyc),
        .wbs_we_i(wbs_we_i),
        .wbs_sel_i(wbs_sel_i),
        .wbs_dat_i(wbs_dat_i),
        .wbs_adr_i(wbs_adr_i),
        .wbs_ack_o(mem_ack),
        .wbs_dat_o(mem_dat),
        .cpu_req_valid(cpu_req_valid),
        .cpu_req_addr(cpu_req_addr),
        .cpu_req_rw(cpu_req_rw),
        .cpu_req_wdata(cpu_req_wdata),
        .cpu_req_ack(cpu_req_ack),
        .cpu_rsp_rdata(cpu_rsp_rdata)
    );

    dma_fir user_dma (
        .clk(wb_clk_i),
        .rst_n(~wb_rst_i),
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
        .wbs_stb_i(wbs_stb_i),
        .wbs_cyc_i(dma_cyc),
        .wbs_we_i(wbs_we_i),
        .wbs_sel_i(wbs_sel_i),
        .wbs_dat_i(wbs_dat_i),
        .wbs_adr_i(wbs_adr_i),
        .wbs_ack_o(dma_ack),
        .wbs_dat_o(dma_dat),
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(ss_tlast),
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(sm_tlast),
        .dma_req_valid(dma_req_valid),
        .dma_req_addr(dma_req_addr),
        .dma_req_rw(dma_req_rw),
        .dma_req_wdata(dma_req_wdata),
        .dma_req_ack(dma_req_ack),
        .dma_rsp_rdata(dma_rsp_rdata),
        .dma_irq(dma_irq)
    );

    fir user_fir (
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(ss_tlast),
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(sm_tlast),
        .tap_WE(tap_WE),
        .tap_EN(tap_EN),
        .tap_Di(tap_Di),
        .tap_A(tap_A),
        .tap_Do(tap_Do),
        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_A(data_A),
        .data_Do(data_Do),
        .axis_clk(wb_clk_i),
        .axis_rst_n(~wb_rst_i)
    );

    bram32 user_tap_ram (
        .CLK(wb_clk_i),
        .WE(tap_WE),
        .EN(tap_EN),
        .Di(tap_Di),
        .Do(tap_Do),
        .A(tap_A)
    );

    bram32 user_data_ram (
        .CLK(wb_clk_i),
        .WE(data_WE),
        .EN(data_EN),
        .Di(data_Di),
        .Do(data_Do),
        .A(data_A)
    );

    arbiter user_arb (
        .clk(wb_clk_i),
        .rst_n(~wb_rst_i),
        .cpu_req_valid(cpu_req_valid),
        .cpu_req_addr(cpu_req_addr),
        .cpu_req_rw(cpu_req_rw),
        .cpu_req_wdata(cpu_req_wdata),
        .cpu_req_ack(cpu_req_ack),
        .cpu_rsp_rdata(cpu_rsp_rdata),
        .dma_req_valid(dma_req_valid),
        .dma_req_addr(dma_req_addr),
        .dma_req_rw(dma_req_rw),
        .dma_req_wdata(dma_req_wdata),
        .dma_req_ack(dma_req_ack),
        .dma_rsp_rdata(dma_rsp_rdata),
        .user_addr(user_addr),
        .rw(rw),
        .data_in(data_in),
        .data_out(data_out),
        .in_valid(in_valid),
        .out_valid(out_valid),
        .arb_busy(arb_busy),
        .arb_row_opened(arb_row_opened),
        .arb_row_addr(arb_row_addr),
        .arb_cache_valid(arb_cache_valid),
        .arb_cache_tag(arb_cache_tag)
    );

    sdram_controller user_sdr_ctrl (
        .clk(wb_clk_i),
        .rst(wb_rst_i),
        .sdram_cle(sdram_cle),
        .sdram_cs(sdram_cs),
        .sdram_cas(sdram_cas),
        .sdram_ras(sdram_ras),
        .sdram_we(sdram_we),
        .sdram_dqm(sdram_dqm),
        .sdram_ba(sdram_ba),
        .sdram_a(sdram_a),
        .sdram_dqi(sdram_dqi),
        .sdram_dqo(sdram_dqo),
        .user_addr(user_addr),
        .rw(rw),
        .data_in(data_in),
        .data_out(data_out),
        .in_valid(in_valid),
        .out_valid(out_valid),
        .arb_busy(arb_busy),
        .arb_row_opened(arb_row_opened),
        .arb_row_addr(arb_row_addr),
        .arb_cache_valid(arb_cache_valid),
        .arb_cache_tag(arb_cache_tag)
    );

    sdr user_sdr (
        .Rst_n(~wb_rst_i),
        .Clk(wb_clk_i),
        .Cke(sdram_cle),
        .Cs_n(sdram_cs),
        .Ras_n(sdram_ras),
        .Cas_n(sdram_cas),
        .We_n(sdram_we),
        .Addr(sdram_a),
        .Ba(sdram_ba),
        .Dqm(sdram_dqm),
        .Dqi(sdram_dqo),
        .Dqo(sdram_dqi)
    );

endmodule