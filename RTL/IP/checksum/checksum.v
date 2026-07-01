`timescale 1ns / 1ps
`default_nettype none

module checksum (
    input  wire        clk,
    input  wire        rst_n,
    
    // AXI-Stream Input
    input  wire [63:0] s_axis_tdata,
    input  wire [7:0]  s_axis_tkeep,
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tready,
    input  wire        s_axis_tlast,
    
    // Checksum Status Output
    output reg         checksum_ok,
    output reg         checksum_valid
);

    // Silence unused s_axis_tkeep warning cleanly
    wire [7:0] _unused_keep = s_axis_tkeep;

    // Protocol state tracking
    reg [1:0] beat_cnt;
    wire fire = s_axis_tvalid && s_axis_tready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            beat_cnt <= 2'd0;
        end else if (fire) begin
            if (s_axis_tlast) begin
                beat_cnt <= 2'd0;
            end else if (beat_cnt < 2'd2) begin
                beat_cnt <= beat_cnt + 1'b1;
            end
        end
    end

    // Slice 64-bit input data into 16-bit words (Big-Endian wire order)
    wire [15:0] w0 = s_axis_tdata[63:48];
    wire [15:0] w1 = s_axis_tdata[47:32];
    wire [15:0] w2 = s_axis_tdata[31:16];
    wire [15:0] w3 = s_axis_tdata[15:0];

    // Pipelined Registers with explicit padding
    reg [16:0] stage1_sum_left;
    reg [16:0] stage1_sum_right;
    reg [19:0] stage2_accum;
    reg [16:0] fold_stage1;
    reg [15:0] final_checksum;
    
    // Pipeline Delay Chains for Flags
    reg        stg1_fire, stg1_tlast;
    reg [1:0]  stg1_beat_cnt;
    reg        stg2_valid, stg2_tlast;
    reg        fold_tlast_d1, fold_tlast_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_sum_left  <= 17'd0;
            stage1_sum_right <= 17'd0;
            stage2_accum    <= 20'd0;
            fold_stage1     <= 17'd0;
            final_checksum  <= 16'd0;
            
            stg1_fire       <= 1'b0;
            stg1_tlast      <= 1'b0;
            stg1_beat_cnt   <= 2'd0;
            stg2_valid      <= 1'b0;
            stg2_tlast      <= 1'b0;
            fold_tlast_d1   <= 1'b0;
            fold_tlast_d2   <= 1'b0;
            
            checksum_ok     <= 1'b0;
            checksum_valid  <= 1'b0;
        end else begin
            // -----------------------------------------------------------------
            // STAGE 1: Parallel Pair Addition (Explicit Width Management)
            // -----------------------------------------------------------------
            stg1_fire     <= fire;
            stg1_tlast    <= fire && s_axis_tlast;
            stg1_beat_cnt <= beat_cnt;

            if (fire) begin
                if (beat_cnt == 2'd2) begin
                    stage1_sum_left  <= {1'b0, w0};
                    stage1_sum_right <= {1'b0, w1};
                end else if (beat_cnt < 2'd2) begin
                    stage1_sum_left  <= {1'b0, w0} + {1'b0, w1};
                    stage1_sum_right <= {1'b0, w2} + {1'b0, w3};
                end else begin
                    stage1_sum_left  <= 17'd0;
                    stage1_sum_right <= 17'd0;
                end
            end

            // -----------------------------------------------------------------
            // STAGE 2: Sum Accumulation
            // -----------------------------------------------------------------
            stg2_valid <= stg1_fire;
            stg2_tlast <= stg1_tlast;

            if (stg1_fire) begin
                if (stg1_beat_cnt == 2'd0) begin
                    stage2_accum <= {3'd0, stage1_sum_left} + {3'd0, stage1_sum_right};
                end else if (stg1_beat_cnt <= 2'd2) begin
                    stage2_accum <= stage2_accum + {3'd0, stage1_sum_left} + {3'd0, stage1_sum_right};
                end
            end

            // -----------------------------------------------------------------
            // STAGE 3: Ones'-Complement Folding
            // -----------------------------------------------------------------
            fold_tlast_d1 <= stg2_valid && stg2_tlast;
            fold_tlast_d2 <= fold_tlast_d1;

            if (stg2_valid && stg2_tlast) begin
                fold_stage1 <= {1'b0, stage2_accum[15:0]} + {13'd0, stage2_accum[19:16]};
            end
            
            if (fold_tlast_d1) begin
                final_checksum <= fold_stage1[15:0] + {15'd0, fold_stage1[16]};
            end

            // -----------------------------------------------------------------
            // STAGE 4: Final Output Generation
            // -----------------------------------------------------------------
            checksum_valid <= fold_tlast_d2;
            if (fold_tlast_d2) begin
                checksum_ok <= (final_checksum == 16'hFFFF);
            end else begin
                checksum_ok <= 1'b0;
            end
        end
    end

endmodule
`default_nettype wire
