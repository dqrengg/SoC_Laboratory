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

`timescale 1 ns / 1 ps

module counter_la_fir_tb;
    reg clock;
    reg RSTB;
    reg CSB;

    reg power1, power2;

    wire gpio;
    wire uart_tx;
    wire [37:0] mprj_io;
    wire [7:0] checkbits;
    wire [7:0] final_y;

    reg [31:0] golden_final_y;

    assign checkbits = mprj_io[23:16];
    assign final_y = mprj_io[31:24];
    assign uart_tx = mprj_io[6];

    always #12.5 clock <= (clock === 1'b0);

    initial begin
        clock = 0;
    end

    `ifdef ENABLE_SDF
        initial begin
            $sdf_annotate("../../../sdf/user_proj_example.sdf", uut.mprj) ;
            $sdf_annotate("../../../sdf/user_project_wrapper.sdf", uut.mprj.mprj) ;
            $sdf_annotate("../../../mgmt_core_wrapper/sdf/DFFRAM.sdf", uut.soc.DFFRAM_0) ;
            $sdf_annotate("../../../mgmt_core_wrapper/sdf/mgmt_core.sdf", uut.soc.core) ;
            $sdf_annotate("../../../caravel/sdf/housekeeping.sdf", uut.housekeeping) ;
            $sdf_annotate("../../../caravel/sdf/chip_io.sdf", uut.padframe) ;
            $sdf_annotate("../../../caravel/sdf/mprj_logic_high.sdf", uut.mgmt_buffers.mprj_logic_high_inst) ;
            $sdf_annotate("../../../caravel/sdf/mprj2_logic_high.sdf", uut.mgmt_buffers.mprj2_logic_high_inst) ;
            $sdf_annotate("../../../caravel/sdf/mgmt_protect_hv.sdf", uut.mgmt_buffers.powergood_check) ;
            $sdf_annotate("../../../caravel/sdf/mgmt_protect.sdf", uut.mgmt_buffers) ;
            $sdf_annotate("../../../caravel/sdf/caravel_clocking.sdf", uut.clocking) ;
            $sdf_annotate("../../../caravel/sdf/digital_pll.sdf", uut.pll) ;
            $sdf_annotate("../../../caravel/sdf/xres_buf.sdf", uut.rstb_level) ;
            $sdf_annotate("../../../caravel/sdf/user_id_programming.sdf", uut.user_id_value) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_bidir_1[0] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_bidir_1[1] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_bidir_2[0] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_bidir_2[1] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_bidir_2[2] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[0] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[1] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[2] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[3] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[4] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[5] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[6] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[7] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[8] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[9] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[10] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1a[0] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1a[1] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1a[2] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1a[3] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1a[4] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1a[5] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[0] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[1] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[2] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[3] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[4] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[5] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[6] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[7] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[8] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[9] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[10] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[11] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[12] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[13] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[14] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_2[15] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.\gpio_defaults_block_0[0] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.\gpio_defaults_block_0[1] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.\gpio_defaults_block_2[0] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.\gpio_defaults_block_2[1] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.\gpio_defaults_block_2[2] ) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_5) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_6) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_7) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_8) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_9) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_10) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_11) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_12) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_13) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_14) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_15) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_16) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_17) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_18) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_19) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_20) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_21) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_22) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_23) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_24) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_25) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_26) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_27) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_28) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_29) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_30) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_31) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_32) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_33) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_34) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_35) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_36) ;
            $sdf_annotate("../../../caravel/sdf/gpio_defaults_block.sdf", uut.gpio_defaults_block_37) ;
        end
    `endif 

    initial begin
        $dumpfile("counter_la_fir.vcd");
        $dumpvars(0, counter_la_fir_tb);
    end

    initial begin
        golden_final_y = 32'd1830;
    end

    integer i;
    integer count;
    initial begin
        for (i = 0; i < 3; i = i + 1) begin
            count = 0;
            wait(checkbits == 8'hA5);
            $display("=========== Start Test %1d ===========", i + 1);
            while (checkbits != 8'h5A) @(posedge clock) count = count + 1;
            if (final_y == golden_final_y[7:0])
                $display("Final Y value correct - golden: 0x%h, final Y: 0x%h", golden_final_y[7:0], final_y);
            else
                $display("Final Y value incorrect - golden: 0x%h, final Y: 0x%h", golden_final_y[7:0], final_y);
            $display("Latency timer: %4d cycles", count);
            $display("============ End Test %1d ============", i + 1);
        end
        #10000;
        $finish;
    end

    initial begin
        RSTB <= 1'b0;
        CSB  <= 1'b1;   // Force CSB high
        #2000;
        RSTB <= 1'b1;   // Release reset
        #170000;
        CSB = 1'b0;     // CSB can be released
    end

    initial begin		// Power-up sequence
        power1 <= 1'b0;
        power2 <= 1'b0;
        #200;
        power1 <= 1'b1;
        #200;
        power2 <= 1'b1;
    end

    wire flash_csb;
    wire flash_clk;
    wire flash_io0;
    wire flash_io1;

    wire VDD1V8;
    wire VDD3V3;
    wire VSS;
    
    assign VDD3V3 = power1;
    assign VDD1V8 = power2;
    assign VSS = 1'b0;

    assign mprj_io[3] = 1;  // Force CSB high.
    assign mprj_io[0] = 0;  // Disable debug mode

    caravel uut (
/*
        .vddio	  (VDD3V3),
        .vddio_2  (VDD3V3),
        .vssio	  (VSS),
        .vssio_2  (VSS),
        .vdda	  (VDD3V3),
        .vssa	  (VSS),
        .vccd	  (VDD1V8),
        .vssd	  (VSS),
        .vdda1    (VDD3V3),
        .vdda1_2  (VDD3V3),
        .vdda2    (VDD3V3),
        .vssa1	  (VSS),
        .vssa1_2  (VSS),
        .vssa2	  (VSS),
        .vccd1	  (VDD1V8),
        .vccd2	  (VDD1V8),
        .vssd1	  (VSS),
        .vssd2	  (VSS),
*/
        .clock    (clock),
        .gpio     (gpio),
        .mprj_io  (mprj_io),
        .flash_csb(flash_csb),
        .flash_clk(flash_clk),
        .flash_io0(flash_io0),
        .flash_io1(flash_io1),
        .resetb	  (RSTB)
    );

    spiflash #(
        .FILENAME("counter_la_fir.modified.hex")
    ) spiflash (
        .csb(flash_csb),
        .clk(flash_clk),
        .io0(flash_io0),
        .io1(flash_io1),
        .io2(),			// not used
        .io3()			// not used
    );

    // Testbench UART
    tbuart tbuart (
        .ser_rx(uart_tx)
    );

endmodule
`default_nettype wire
