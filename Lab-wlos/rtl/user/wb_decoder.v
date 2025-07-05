module wb_decoder (
    // user project
    input         mprj_cyc,
    input  [31:0] mprj_adr,
    output        mprj_ack,
    output [31:0] mprj_dat,
    // fir dma
    output        dma_cyc,
    input         dma_ack,
    input  [31:0] dma_dat,
    // exme,
    output        mem_cyc,
    input         mem_ack,
    input  [31:0] mem_dat
);
    wire mem_sel, dma_sel;

    assign mem_sel = (mprj_adr[31:24] == 8'h38);
    assign dma_sel = (mprj_adr[31:24] == 8'h30);
    assign mem_cyc = mprj_cyc & mem_sel;
    assign dma_cyc = mprj_cyc & dma_sel;

    assign mprj_ack = mem_ack | dma_ack;
    assign mprj_dat = ({ 32{mem_sel} } & mem_dat) | ({ 32{dma_sel} } & dma_dat);

endmodule