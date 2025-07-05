module sdram_controller (
    input  clk,
    input  rst,

    output        sdram_cle,
    output        sdram_cs,
    output        sdram_cas,
    output        sdram_ras,
    output        sdram_we,
    output [3:0]  sdram_dqm,
    output [1:0]  sdram_ba,
    output [12:0] sdram_a,
    input  [31:0] sdram_dqi,
    output [31:0] sdram_dqo,

    // User interface
    // Note: we want to remap addr (see below)
    // input [22:0] addr,       // address to read/write
    input  [22:0] user_addr,   // the address will be remap to addr later
    input         rw,          // 1 = write, 0 = read
    input  [31:0] data_in,     // data from a read
    output [31:0] data_out,    // data for a write
    input         in_valid,    // pulse high to initiate a read/write
    output        out_valid,   // pulses high when data from read is valid

    output [3:0]  arb_busy,        // packed
    output [3:0]  arb_row_opened,  // packed
    output [51:0] arb_row_addr,    // packed
    output [3:0]  arb_cache_valid, // packed
    output [67:0] arb_cache_tag    // packed
);

    // Jiin: SDRAM Timing  3-3-3, i.e. CASL=3, PRE=3, ACT=3
    localparam tCASL            = 13'd2;       // 3T actually
    localparam tPRE             = 13'd2;       // 3T
    localparam tACT             = 13'd2;       // 3T
    localparam tREF             = 13'd6;       // 7T
    localparam tRef_Counter     = 10'd750;     // 

    localparam burst_length = 3; // 4 words actually,

    // Commands for the SDRAM
    localparam CMD_UNSELECTED    = 4'b1000;
    localparam CMD_NOP           = 4'b0111;
    localparam CMD_ACTIVE        = 4'b0011;
    localparam CMD_READ          = 4'b0101;
    localparam CMD_WRITE         = 4'b0100;
    localparam CMD_TERMINATE     = 4'b0110;
    localparam CMD_PRECHARGE     = 4'b0010;
    localparam CMD_REFRESH       = 4'b0001;
    localparam CMD_LOAD_MODE_REG = 4'b0000;
    
    // bank FSM
    localparam WAIT = 4'd0,
               IDLE = 4'd1,
               ACTIVATE = 4'd2,
               READ = 4'd3,
               READ_RES = 4'd4,
               WRITE = 4'd5,
               PRECHARGE = 4'd6;

    // global FSM
    localparam GLOBAL_INIT = 4'd0,
               GLOBAL_WAIT = 4'd1,
            //    PRECHARGE_INIT = 4'd2,
            //    REFRESH_INIT_1 = 4'd3,
            //    REFRESH_INIT_2 = 4'd4,
            //    LOAD_MODE_REG = 4'd5,
               GLOBAL_PRECHARGE_ALL = 4'd6,
               GLOBAL_REFRESH = 4'd7,
               GLOBAL_WAIT_REFRESH = 4'd8;

    reg [12:0] a_q;
    reg [1:0]  ba_q;
    reg [3:0]  cmd_q;

    wire global_en;

    // Address Remap
    wire [12:0] Mapped_RA;
    wire [1:0]  Mapped_BA;
    wire [7:0]  Mapped_CA;
    assign Mapped_RA = { user_addr[22:15], user_addr[13:9] }; // user_addr[22:10];
    assign Mapped_BA = { user_addr[14],    user_addr[4]    }; // user_addr[9:8];
    assign Mapped_CA = { user_addr[8:5],   user_addr[3:0]  }; // user_addr[7:0];

    reg [31:0] data_q, dq_q, dqi_q;
    reg dq_en;

    reg out_valid_q;

    reg cle;

    reg [3:0]  global_state, global_next_state;
    reg [15:0] global_delay_ctr;
    reg [15:0] refresh_ctr;

    reg [3:0]  global_cmd;
    reg [12:0] global_a;

    reg init_done, refresh_req;

    reg [3:0]  state[0:3], next_state[0:3];
    reg [15:0] delay_ctr[0:3];
    reg [1:0]  burst_ctr[0:3];
    reg [1:0]  burst_idx[0:3];

    reg [3:0]  cmd[0:3];
    reg [12:0] a[0:3];
    reg [12:0] row_addr[0:3];
    reg [7:0]  col_addr[0:3];
    reg [12:0] row_opened_addr[0:3];
    reg        row_opened_flag[0:3];
    reg        rw_op[0:3];
    reg [31:0] wdata[0:3];
    reg        prefetch_flag[0:3];

    // bank FSM out
    reg        bank_busy[0:3];
    reg        cmd_ready[0:3];
    reg        cmd_read[0:3];

    // bank FSM in
    wire bank_sel[0:3];
    wire issue_cmd_en[0:3];
    reg start_op[0:3];

    wire issue_read_en;
    wire read_issued;

    reg [6:0]  dq_busy_shift_regs;

    reg [16:0] cache_tag[0:3];
    reg [31:0] cache_data[0:3][0:3];
    reg        cache_valid[0:3];

    wire [1:0]  cache_idx;
    wire [16:0] user_tag;
    wire        cache_hit;
    wire [31:0] cache_rdata;

    // RR scheduler
    reg  [3:0] mask;
    wire [3:0] unmasked_rr_req;
    wire [3:0] masked_rr_req;
    wire [3:0] unmasked_pre_req;
    wire [3:0] masked_pre_req;
    wire [3:0] unmasked_rr_gnt;
    wire [3:0] masked_rr_gnt;
    wire [3:0] rr_gnt;
    wire       no_mask;

    assign global_en = (!init_done || refresh_req);

    // Output assignments
    assign sdram_cle = cle;
    assign { sdram_cs, sdram_ras, sdram_cas, sdram_we } = global_en ? global_cmd : cmd_q;
    assign sdram_dqm = 4'b1111; //dqm_q; // TODO
    assign sdram_ba = ba_q;
    assign sdram_a = global_en ? global_a : a_q;
    assign sdram_dqo = dq_en ? dq_q : 32'hZZZZZZZZ;

    assign data_out = data_q;
    assign out_valid = out_valid_q;

    // packed output
    assign arb_busy        = { bank_busy[3], bank_busy[2], bank_busy[1], bank_busy[0] };
    assign arb_row_opened  = { row_opened_flag[3], row_opened_flag[2], row_opened_flag[1], row_opened_flag[0] };
    assign arb_row_addr    = { row_opened_addr[3], row_opened_addr[2], row_opened_addr[1], row_opened_addr[0] };
    assign arb_cache_valid = { cache_valid[3], cache_valid[2], cache_valid[1], cache_valid[0] };
    assign arb_cache_tag   = { cache_tag[3], cache_tag[2], cache_tag[1], cache_tag[0] };

    assign cache_idx = user_addr[3:2];
    assign user_tag = { Mapped_RA, Mapped_CA[7:4] };
    assign cache_hit = (cache_valid[Mapped_BA] && cache_tag[Mapped_BA] == user_tag);
    assign cache_rdata = cache_data[Mapped_BA][cache_idx];

    assign issue_read_en = ~dq_busy_shift_regs[5];
    
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            global_state <= GLOBAL_INIT;
            cle <= 1'b0;
            init_done <= 1'b0;
            refresh_req <= 1'b0;
            out_valid_q <= 1'b0;
        end else begin
            dqi_q <= sdram_dqi;

            case (global_state)
                GLOBAL_INIT: begin
                    for (i = 0; i < 4; i = i + 1) begin
                        state[i] <= IDLE;
                        row_opened_flag[i] <= 1'b0;
                        cache_valid[i] <= 1'b0;
                        bank_busy[i] <= 1'b0;
                        start_op[i] <= 1'b0;
                        cmd_ready[i] <= 1'b0;
                        prefetch_flag[i] <= 1'b0;
                    end
                    
                    // global_cmd <= CMD_LOAD_MODE_REG
                    // mode regs
                    // Reserved, Burst Access, Standard Op, CAS = 2, Seq, Burst = 4
                    // a <= { 3'b000, 1'b0, 2'b00, 3'b010, 1'b0, 3'b010 };

                    cle <= 1'b1;

                    global_state <= GLOBAL_WAIT;
                    global_cmd <= CMD_NOP;
                    global_delay_ctr <= 16'd0;
                    global_next_state <= GLOBAL_WAIT_REFRESH;

                    refresh_ctr <= tRef_Counter;
                    refresh_req <= 1'b0;
                    
                    dq_en <= 1'b0;
                    out_valid_q <= 1'b0;
                end
                GLOBAL_WAIT: begin
                    if (global_delay_ctr == 0) begin
                        global_state <= global_next_state;
                        case (global_next_state)
                            GLOBAL_REFRESH: begin
                                global_cmd <= CMD_REFRESH;
                            end
                            GLOBAL_WAIT_REFRESH: begin
                                init_done <= 1'b1;
                                refresh_req <= 1'b0;
                                for (i = 0; i < 4; i = i + 1) begin
                                    bank_busy[i] <= 1'b0;
                                    row_opened_flag[i] <= 1'b0;
                                end
                            end
                        endcase
                    end else begin
                        global_delay_ctr <= global_delay_ctr - 1;
                    end
                end
                GLOBAL_PRECHARGE_ALL: begin
                    global_state <= GLOBAL_WAIT;
                    global_cmd <= CMD_NOP;
                    global_delay_ctr <= tPRE;
                    global_next_state <= GLOBAL_REFRESH;
                end
                GLOBAL_REFRESH: begin
                    global_state <= GLOBAL_WAIT;
                    global_cmd <= CMD_NOP;
                    global_delay_ctr <= tREF;
                    global_next_state <= GLOBAL_WAIT_REFRESH;
                end
                GLOBAL_WAIT_REFRESH: begin
                    /*if (refresh_ctr == 1) begin
                        global_state <= GLOBAL_PRECHARGE_ALL;
                        global_cmd <= CMD_PRECHARGE;
                        global_a[10] <= 1'b1;
                        refresh_ctr <= tRef_Counter;
                        refresh_req <= 1'b1;

                        for (i = 0; i < 4; i = i + 1) bank_busy[i] <= 1'b1;
                    end else begin
                        refresh_ctr <= refresh_ctr - 1;
                    end*/
                end
                default: global_state <= GLOBAL_INIT;
            endcase

            if (in_valid && !bank_busy[Mapped_BA]) begin
                if (!rw && cache_hit) begin
                    data_q <= cache_rdata;
                    out_valid_q <= 1'b1;
                end else begin
                    start_op[Mapped_BA] <= 1'b1;

                    bank_busy[Mapped_BA] <= 1'b1;
                    
                    row_addr[Mapped_BA] <= Mapped_RA;
                    col_addr[Mapped_BA] <= Mapped_CA;
                    rw_op[Mapped_BA] <= rw;
                    wdata[Mapped_BA] <= data_in;

                    out_valid_q <= 1'b0;
                end
            end else begin
                out_valid_q <= 1'b0;
            end

            for (i = 0; i < 4; i = i + 1) begin
                case (state[i])
                WAIT: begin
                    if (delay_ctr[i] == 13'd0) begin
                        state[i] <= next_state[i];
                        
                        case (next_state[i])
                            IDLE: begin
                                cmd[i] <= CMD_NOP;
                                bank_busy[i] <= 1'b0;
                            end
                            ACTIVATE: begin
                                cmd[i] <= CMD_ACTIVE;
                                a[i] <= row_addr[i];
                                cmd_ready[i] <= 1'b1;
                            end
                            READ: begin
                                cmd[i] <= CMD_READ;
                                a[i] <= { 7'b0, col_addr[i][7:2] };
                                cmd_ready[i] <= 1'b1;
                            end
                            READ_RES: begin
                                if (!prefetch_flag[i]) begin
                                    data_q <= sdram_dqi;
                                    out_valid_q <= 1'b1;
                                end
                            end
                            WRITE: begin
                                cmd[i] <= CMD_WRITE;
                                a[i] <= { 7'b0, col_addr[i][7:2] };
                                cmd_ready[i] <= 1'b1;

                                dq_en <= 1'b1;
                                dq_q <= wdata[i];
                            end
                        endcase
                    end else begin
                        delay_ctr[i] <= delay_ctr[i] - 1'b1;
                    end
                end
                IDLE: begin
                    if (start_op[i]) begin // operation waiting
                        start_op[i] <= 1'b0;
                        cmd_ready[i] <= 1'b1;
                        if (row_opened_flag[i]) begin // if the row opened, we don't have to activate it
                            if (row_opened_addr[i] == row_addr[i]) begin // row opened
                                if (rw_op[i]) begin // write
                                    state[i] <= WRITE;
                                    cmd[i] <= CMD_WRITE;
                                    a[i] <= { 7'b0, col_addr[i][7:2] };
                                    dq_q <= wdata[i];
                                    dq_en <= 1'b1;
                                end else begin // read
                                    state[i] <= READ;
                                    cmd[i] <= CMD_READ;
                                    a[i] <= { 7'b0, col_addr[i][7:2] };
                                end
                            end else begin // different row opened 
                                state[i] <= PRECHARGE; // precharge opened row
                                next_state[i] <= ACTIVATE; // open current row
                                cmd[i] <= CMD_PRECHARGE;
                                a[i][10] <= 1'b0;
                            end
                        end else begin // no row opened
                            state[i] <= ACTIVATE; // open the row
                            cmd[i] <= CMD_ACTIVE;
                            a[i] <= row_addr[i];
                        end
                    end
                end
                ACTIVATE: begin
                    if (issue_cmd_en[i]) begin
                        state[i] <= WAIT;
                        cmd[i] <= CMD_NOP;
                        delay_ctr[i] <= tACT;
                        if (rw_op[i]) next_state[i] <= WRITE;
                        else          next_state[i] <= READ;

                        row_opened_flag[i] <= 1'b1; // row is now open
                        row_opened_addr[i] <= row_addr[i];

                        cmd_ready[i] <= 1'b0;
                    end
                end
                READ: begin
                    if (issue_cmd_en[i]) begin
                        state[i] <= WAIT;
                        cmd[i] <= CMD_NOP;
                        delay_ctr[i] <= tCASL; 
                        next_state[i] <= READ_RES;

                        cmd_ready[i] <= 1'b0;

                        burst_ctr[i] <= burst_length;
                        burst_idx[i] <= col_addr[i][3:2];
                        //if (!prefetch_flag[i])
                    end
                end
                READ_RES: begin
                    burst_ctr[i] <= burst_ctr[i] - 1'b1;
                    burst_idx[i] <= burst_idx[i] + 1'b1;

                    cache_data[i][burst_idx[i]] <= dqi_q;

                    out_valid_q <= 1'b0; // TODO

                    if (burst_ctr[i] == 0) begin
                        state[i] <= IDLE;
                        
                        bank_busy[i] <= 1'b0;

                        cache_tag[i] <= { row_addr[i], col_addr[i][7:4] };
                        cache_valid[i] <= 1'b1;
                    end
                end
                WRITE: begin
                    if (issue_cmd_en[i]) begin
                        dq_en <= 1'b0; // TODO: reset logic

                        state[i] <= IDLE;
                        cmd[i] <= CMD_NOP;
                        bank_busy[i] <= 1'b0;

                        cmd_ready[i] <= 1'b0;
                    end
                end
                PRECHARGE: begin                    
                    if (issue_cmd_en[i]) begin
                        state[i] <= WAIT;
                        cmd[i] <= CMD_NOP;
                        delay_ctr[i] = tPRE;

                        row_opened_flag[i] = 1'b0; // row closed

                        cmd_ready[i] <= 1'b0;
                    end
                end
                default: state[i] <= IDLE;
                endcase
            end
        end
    end

    genvar j;
    generate
        for (j = 0; j < 4; j = j + 1) begin: bank_gen
            assign bank_sel[j] = (Mapped_BA == j);
            // assign start_op[j] = bank_sel[j] & !cache_hit; // latch
            assign issue_cmd_en[j] = rr_gnt[j];
            assign unmasked_rr_req[j] = cmd_ready[j] & (~cmd_read[j] | issue_read_en);
        end
    endgenerate

    always @(*) begin
        case (rr_gnt)
        4'b0001: begin ba_q = 2'b00; a_q = a[0]; cmd_q = cmd[0]; end
        4'b0010: begin ba_q = 2'b01; a_q = a[1]; cmd_q = cmd[1]; end
        4'b0100: begin ba_q = 2'b10; a_q = a[2]; cmd_q = cmd[2]; end
        4'b1000: begin ba_q = 2'b11; a_q = a[3]; cmd_q = cmd[3]; end
        default: begin ba_q = 2'b00; a_q = 13'b0; cmd_q = CMD_NOP; end
        endcase
    end
    
    // assign unmasked_rr_req = { cmd_ready[3], cmd_ready[2], cmd_ready[1], cmd_ready[0] } 
    //                        & (~{ cmd_read[3], cmd_read[2], cmd_read[1], cmd_read[0] } | { 4{issue_read_en} });
    assign masked_rr_req = unmasked_rr_req & mask;
    assign unmasked_pre_req = { (unmasked_pre_req[2:0] | unmasked_rr_req[2:0]), 1'b0 };
    assign masked_pre_req = { (masked_pre_req[2:0] | masked_rr_req[2:0]), 1'b0 };
    assign unmasked_rr_gnt = unmasked_rr_req & ~unmasked_pre_req;
    assign masked_rr_gnt = masked_rr_req & ~masked_pre_req;

    assign no_mask = ~|masked_rr_gnt;
    assign rr_gnt = (!no_mask) ? masked_rr_gnt : unmasked_rr_gnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mask <= 4'b1111;
        end else begin
            if (|masked_pre_req) begin
                mask <= masked_pre_req;
            end else if (|unmasked_pre_req) begin
                mask <= unmasked_pre_req;
            end
        end
    end

    assign read_issued = cmd_read[ba_q];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dq_busy_shift_regs <= 7'b0000000;
        end else begin
            if (read_issued) dq_busy_shift_regs <= { 4'b1111, dq_busy_shift_regs[3:1]};
            else dq_busy_shift_regs <= { 1'b0, dq_busy_shift_regs[6:1] };
        end
    end

    wire [3:0] state0, state1, state2, state3;
    assign state0 = state[0];
    assign state1 = state[1];
    assign state2 = state[2];
    assign state3 = state[3];

    wire op_start0;
    wire op_start1;
    wire op_start2;
    wire op_start3;
    assign op_start0 = start_op[0];
    assign op_start1 = start_op[1];
    assign op_start2 = start_op[2];
    assign op_start3 = start_op[3];

    wire cmd_ready0;
    wire cmd_ready1;
    wire cmd_ready2;
    wire cmd_ready3;
    assign cmd_ready0 = cmd_ready[0];
    assign cmd_ready1 = cmd_ready[1];
    assign cmd_ready2 = cmd_ready[2];
    assign cmd_ready3 = cmd_ready[3];

    wire rw_op0;
    wire rw_op1;
    wire rw_op2;
    wire rw_op3;
    assign rw_op0 = rw_op[0];
    assign rw_op1 = rw_op[1];
    assign rw_op2 = rw_op[2];
    assign rw_op3 = rw_op[3];

    wire [1:0] burst_idx0;
    wire [1:0] burst_idx1;
    wire [1:0] burst_idx2;
    wire [1:0] burst_idx3;
    assign burst_idx0 = burst_idx[0];
    assign burst_idx1 = burst_idx[1];
    assign burst_idx2 = burst_idx[2];
    assign burst_idx3 = burst_idx[3];

endmodule