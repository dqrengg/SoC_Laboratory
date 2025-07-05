module dma_fir (
    input clk,
    input rst_n,
    // dma controller wb interface
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
    // dma-fir interface
    input         awready,
    input         wready,
    output        awvalid,
    output [11:0] awaddr,
    output        wvalid,
    output [31:0] wdata,

    input         arready,
    output        rready,
    output        arvalid,
    output [11:0] araddr,
    input         rvalid,
    input  [31:0] rdata,

    output        ss_tvalid,
    output [31:0] ss_tdata,
    output        ss_tlast,
    input         ss_tready,

    output        sm_tready,
    input         sm_tvalid,
    input  [31:0] sm_tdata,
    input         sm_tlast,
    // dma-arbiter interface
    output        dma_req_valid,
    output [22:0] dma_req_addr,
    output        dma_req_rw,
    output [31:0] dma_req_wdata,
    input         dma_req_ack,
    input  [31:0] dma_rsp_rdata,
    // irq
    output        dma_irq
);
    localparam STATE_IDLE        =  0;
    localparam STATE_LW_SEND_REQ =  1;
    localparam STATE_LW_WAIT_RDY =  2;
    localparam STATE_DL_WAIT_RDY =  3;
    localparam STATE_AP_WAIT_RDY =  4;
    localparam STATE_SS_SEND_REQ =  5;
    localparam STATE_SS_WAIT_RDY =  6;
    localparam STATE_SM_WAIT_VLD =  7;
    localparam STATE_SM_SEND_REQ =  8;
    localparam STATE_AP_WAIT_VLD =  9;
    localparam STATE_DONE        = 10;

    localparam FIR_AP_ADDR  = 12'h000;
    localparam FIR_DL_ADDR  = 12'h010;
    localparam FIR_TAP_BASE = 12'h080;

    localparam AXIS_BUF_SIZE = 4;

    localparam MMAP_DMA_START    = 8'h00;
    localparam MMAP_SDR_TAP_BASE = 8'h04;
    localparam MMAP_SDR_X_BASE   = 8'h08;
    localparam MMAP_SDR_Y_BASE   = 8'h0C;
    localparam MMAP_TAP_NUM      = 8'h10;
    localparam MMAP_DATA_LENGTH  = 8'h14;

    reg [22:0] sdr_x_base, sdr_y_base, sdr_tap_base;
    reg [6:0]  data_length;
    reg [5:0]  tap_num;

    reg [5:0]  tap_count;
    reg [6:0]  sm_count, ss_count;
    reg [2:0]  sm_loop_count, ss_loop_count;

    reg [11:0] fir_tap_ptr;
    reg [22:0] sdr_x_ptr, sdr_y_ptr, sdr_tap_ptr;

    reg [3:0]  state, next_state;

    reg        awvalid_q;
    reg [11:0] awaddr_q;
    reg        wvalid_q;
    reg [31:0] wdata_q;

    reg        w_done, aw_done;

    reg        arvalid_q;
    reg        rready_q;

    reg        ss_tvalid_q;
    reg [31:0] ss_tdata_q;
    // reg        ss_tlast_q;

    reg        sm_tready_q;
    
    reg        dma_req_valid_q;
    reg [22:0] dma_req_addr_q;
    reg        dma_req_rw_q;
    reg [31:0] dma_req_wdata_q;

    wire wb_wvalid;
    
    wire dma_start_sel;
    wire sdr_x_base_sel, sdr_y_base_sel, sdr_tap_base_sel;
    wire data_length_sel, tap_num_sel;
    
    wire dma_start;

    assign awvalid = awvalid_q;
    assign awaddr  = awaddr_q;
    assign wvalid  = wvalid_q;
    assign wdata   = wdata_q;

    assign arvalid = arvalid_q;
    assign rready  = rready_q;

    assign ss_tvalid = (state == STATE_SS_SEND_REQ && dma_req_ack) | ss_tvalid_q;
    assign ss_tdata  = (state == STATE_SS_SEND_REQ && dma_req_ack) ? dma_rsp_rdata : ss_tdata_q;
    assign ss_tlast  = ss_tvalid & (ss_count == 1);
    
    assign sm_tready = sm_tready_q;

    assign dma_req_valid = dma_req_valid_q;
    assign dma_req_addr  = dma_req_addr_q;
    assign dma_req_rw    = dma_req_rw_q;
    assign dma_req_wdata = dma_req_wdata_q;

    assign wb_wvalid = wbs_cyc_i & wbs_stb_i & wbs_we_i;

    assign wbs_ack_o = wbs_cyc_i & wbs_stb_i;

    assign dma_irq = (state == STATE_DONE);

    assign dma_start_sel    = (wbs_adr_i[7:0] == MMAP_DMA_START);
    assign sdr_x_base_sel   = (wbs_adr_i[7:0] == MMAP_SDR_X_BASE);
    assign sdr_y_base_sel   = (wbs_adr_i[7:0] == MMAP_SDR_Y_BASE);
    assign sdr_tap_base_sel = (wbs_adr_i[7:0] == MMAP_SDR_TAP_BASE);
    assign tap_num_sel      = (wbs_adr_i[7:0] == MMAP_TAP_NUM);
    assign data_length_sel  = (wbs_adr_i[7:0] == MMAP_DATA_LENGTH);
    
    assign dma_start = wb_wvalid & dma_start_sel && (wbs_dat_i == 32'h0000_0001);

    // wb cfg
    always @(posedge clk) begin
        if (wb_wvalid) begin
            if (sdr_x_base_sel)   sdr_x_base   <= wbs_dat_i[22:0];
            if (sdr_y_base_sel)   sdr_y_base   <= wbs_dat_i[22:0];
            if (sdr_tap_base_sel) sdr_tap_base <= wbs_dat_i[22:0];
            if (tap_num_sel)      tap_num      <= wbs_dat_i[5:0];
            if (data_length_sel)  data_length  <= wbs_dat_i[6:0];
        end
    end

    // FSM seq
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM comb
    always @(*) begin
        case (state)
        STATE_IDLE: begin
            next_state = dma_start ? STATE_LW_SEND_REQ : STATE_IDLE;
        end
        STATE_LW_SEND_REQ: begin
            /*if (dma_req_ack && awready && wready && tap_count == 1)
                next_state = STATE_DL_WAIT_RDY;  // last request
            else if (dma_req_ack && awready && wready)
                next_state = STATE_LW_SEND_REQ;  // next request
            else */
            if (dma_req_ack)
                next_state = STATE_LW_WAIT_RDY;
            else
                next_state = STATE_LW_SEND_REQ;  // current request
        end
        STATE_LW_WAIT_RDY: begin
            if ((aw_done || awready) && (w_done || wready) && tap_count == 1)
                next_state = STATE_DL_WAIT_RDY;  // last request
            else if ((aw_done || awready) && (w_done || wready))
                next_state = STATE_LW_SEND_REQ;  // next request
            else
                next_state = STATE_LW_WAIT_RDY;
        end
        STATE_DL_WAIT_RDY: begin
            if (awready && wready) 
                next_state = STATE_AP_WAIT_RDY;
            else
                next_state = STATE_DL_WAIT_RDY;
        end
        STATE_AP_WAIT_RDY: begin
            if (awready && wready) 
                next_state = STATE_SS_SEND_REQ;
            else
                next_state = STATE_AP_WAIT_RDY;
        end
        STATE_SS_SEND_REQ: begin
            if (dma_req_ack && ss_tready && (ss_loop_count == 1 || ss_count == 1))
                next_state = STATE_SM_WAIT_VLD;  // end of loop
            else if (dma_req_ack && ss_tready)
                next_state = STATE_SS_SEND_REQ;  // next request
            else if (dma_req_ack)
                next_state = STATE_SS_WAIT_RDY;
            else
                next_state = STATE_SS_SEND_REQ;  // current request
        end
        STATE_SS_WAIT_RDY: begin
            if (ss_tready && (ss_loop_count == 1 || ss_count == 1))
                next_state = STATE_SM_WAIT_VLD;  // end of loop
            else if (ss_tready)
                next_state = STATE_SS_SEND_REQ;
            else
                next_state = STATE_SS_WAIT_RDY;
        end
        STATE_SM_WAIT_VLD: begin
            if (sm_tvalid)
                next_state = STATE_SM_SEND_REQ;
            else
                next_state = STATE_SM_WAIT_VLD;
        end
        STATE_SM_SEND_REQ: begin
            if (dma_req_ack && sm_count == 1)
                next_state = STATE_DONE;         // last request
            else if (dma_req_ack && sm_loop_count == 1)
                next_state = STATE_SS_SEND_REQ;  // end of loop
            // else if (dma_req_ack && sm_tvalid)
            //     next_state = STATE_SM_SEND_REQ;
            else if (dma_req_ack)
                next_state = STATE_SM_WAIT_VLD;
            else
                next_state = STATE_SM_SEND_REQ;
        end
        STATE_DONE: begin
            next_state = STATE_IDLE;
        end
        default: begin
            next_state = STATE_IDLE;
        end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_req_valid_q <= 0;

            awvalid_q       <= 0;
            wvalid_q        <= 0;
            aw_done         <= 0;
            w_done         <= 0;

            arvalid_q       <= 0;
            rready_q        <= 0;

            ss_tvalid_q     <= 0;
            sm_tready_q     <= 0;
        end else begin
            case (state)
            STATE_IDLE: begin
                if (dma_start) begin
                    tap_count       <= tap_num;
                    sdr_tap_ptr     <= sdr_tap_base;
                    fir_tap_ptr     <= FIR_TAP_BASE;

                    ss_count        <= data_length;
                    ss_loop_count   <= AXIS_BUF_SIZE;
                    sdr_x_ptr       <= sdr_x_base;

                    sm_count        <= data_length;
                    sm_loop_count   <= AXIS_BUF_SIZE;
                    sdr_y_ptr       <= sdr_y_base;
                    
                    dma_req_addr_q  <= sdr_tap_base;
                    dma_req_valid_q <= 1;
                    dma_req_rw_q    <= 0;

                    ss_tvalid_q     <= 0;

                    sm_tready_q     <= 0;
                end
            end
            STATE_LW_SEND_REQ: begin
                if (dma_req_ack) begin
                    dma_req_valid_q <= 0;
                    dma_req_addr_q  <= sdr_tap_ptr + 4;
                    sdr_tap_ptr     <= sdr_tap_ptr + 4;
                    awvalid_q       <= 1;
                    awaddr_q        <= fir_tap_ptr;
                    wvalid_q        <= 1;
                    wdata_q         <= dma_rsp_rdata;
                end
                
            end
            STATE_LW_WAIT_RDY: begin
                if (awready && !w_done && !wready) begin
                    awvalid_q       <= 0;
                    aw_done         <= 1;
                end
                if (wready && !aw_done && !awready) begin
                    wvalid_q        <= 0;
                    w_done          <= 1;
                end
                if ((aw_done || awready) && (w_done || wready) && tap_count == 1) begin
                    dma_req_valid_q <= 0;
                    
                    awvalid_q       <= 1;
                    awaddr_q        <= FIR_DL_ADDR;
                    wvalid_q        <= 1;
                    wdata_q         <= {25'b0, data_length};
                    aw_done         <= 0;
                    w_done          <= 0;
                end else if ((aw_done || awready) && (w_done || wready)) begin
                    dma_req_valid_q <= 1;
                    
                    awvalid_q       <= 0;
                    wvalid_q        <= 0;
                    aw_done         <= 0;
                    w_done          <= 0;
                    
                    tap_count       <= tap_count - 1;
                    fir_tap_ptr     <= fir_tap_ptr + 4;
                end
            end
            STATE_DL_WAIT_RDY: begin
                if (awready && !w_done && !wready) begin
                    awvalid_q       <= 0;
                    aw_done         <= 1;
                end
                if (wready && !aw_done && !awready) begin
                    wvalid_q        <= 0;
                    w_done          <= 1;
                end
                if ((aw_done || awready) && (w_done || wready)) begin
                    awvalid_q       <= 1;
                    awaddr_q        <= FIR_AP_ADDR;
                    wvalid_q        <= 1;
                    wdata_q         <= 32'h0000_0001;
                    aw_done         <= 0;
                    w_done          <= 0;
                end
            end
            STATE_AP_WAIT_RDY: begin
                if (awready && !w_done && !wready) begin
                    awvalid_q       <= 0;
                    aw_done         <= 1;
                end
                if (wready && !aw_done && !awready) begin
                    wvalid_q        <= 0;
                    w_done          <= 1;
                end
                if ((aw_done || awready) && (w_done || wready)) begin
                    dma_req_valid_q <= 1;
                    dma_req_addr_q  <= sdr_x_ptr;
                    dma_req_rw_q    <= 0;

                    awvalid_q       <= 0;
                    wvalid_q        <= 0;
                    aw_done         <= 0;
                    w_done          <= 0;

                    sdr_x_ptr       <= sdr_x_ptr + 4;
                end
            end
            STATE_SS_SEND_REQ: begin
                if (dma_req_ack && ss_tready && (ss_loop_count == 1 || ss_count == 1)) begin
                    dma_req_valid_q <= 0;   
                    
                    sm_tready_q     <= 1;
                    
                    ss_count        <= ss_count - 1;
                    ss_loop_count   <= AXIS_BUF_SIZE;
                end else if (dma_req_ack && ss_tready) begin
                    dma_req_valid_q <= 1;
                    dma_req_addr_q  <= sdr_x_ptr;
                    
                    sdr_x_ptr       <= sdr_x_ptr + 4;
                    ss_count        <= ss_count - 1;
                    ss_loop_count   <= ss_loop_count - 1;
                end else if (dma_req_ack) begin
                    dma_req_valid_q <= 0;
                    
                    ss_tvalid_q     <= 1;
                    ss_tdata_q      <= dma_rsp_rdata;
                end
            end
            STATE_SS_WAIT_RDY: begin
                if (ss_tready && (ss_loop_count == 1 || ss_count == 1)) begin
                    dma_req_valid_q <= 0;
                    
                    sm_tready_q     <= 1;
                    
                    ss_count        <= ss_count - 1;
                    ss_loop_count   <= AXIS_BUF_SIZE;
                end else if (ss_tready) begin
                    dma_req_valid_q <= 1;
                    dma_req_addr_q  <= sdr_x_ptr;
                    
                    sdr_x_ptr       <= sdr_x_ptr + 4;
                    ss_count        <= ss_count - 1;
                    ss_loop_count   <= ss_loop_count - 1;
                end
            end
            STATE_SM_WAIT_VLD: begin
                if (sm_tvalid) begin
                    dma_req_valid_q <= 1;
                    dma_req_addr_q  <= sdr_y_ptr;
                    dma_req_rw_q    <= 1;
                    dma_req_wdata_q <= sm_tdata;

                    sm_tready_q     <= 0;
                    
                    sdr_y_ptr       <= sdr_y_ptr + 4;
                end
            end
            STATE_SM_SEND_REQ: begin
                if (dma_req_ack && sm_count == 1) begin
                    dma_req_valid_q <= 0;
                end else if (dma_req_ack && sm_loop_count == 1) begin
                    dma_req_valid_q <= 1;
                    dma_req_addr_q  <= sdr_x_ptr;
                    dma_req_rw_q    <= 0;
                    
                    sdr_x_ptr       <= sdr_x_ptr + 4;
                    sm_count        <= sm_count - 1;
                    sm_loop_count   <= AXIS_BUF_SIZE;
                /*end else if (dma_req_ack && sm_tvalid) begin
                    dma_req_valid_q <= 1;
                    dma_req_addr_q  <= sdr_y_ptr;
                    dma_req_wdata_q <= sm_tdata;
                    
                    sdr_y_ptr       <= sdr_y_ptr + 4;
                    sm_count        <= sm_count - 1;
                    sm_loop_count   <= sm_loop_count - 1;
                */
                end else if (dma_req_ack) begin
                    dma_req_valid_q <= 0;

                    sm_tready_q     <= 1;
                    
                    sm_count        <= sm_count - 1;
                    sm_loop_count   <= sm_loop_count - 1;
                end
            end
            default: begin
                ;
            end
            endcase
        end
    end

endmodule