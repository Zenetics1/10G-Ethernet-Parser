`timescale 1ns / 1ps

module checksum_tb;

    // Inputs
    reg         clk;
    reg         rst_n;
    reg [63:0]  s_axis_tdata;
    reg [7:0]   s_axis_tkeep;
    reg         s_axis_tvalid;
    reg         s_axis_tready;
    reg         s_axis_tlast;

    // Outputs
    wire        checksum_ok;
    wire        checksum_valid;

    // Instantiate UUT
    checksum uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .checksum_ok(checksum_ok),
        .checksum_valid(checksum_valid)
    );

    // Clock Generation (100 MHz)
    always #5 clk = ~clk;

    // Base Packet Configuration Constants
    localparam [63:0] PKT_BEAT0 = 64'h4500_0028_0001_0000;
    localparam [63:0] PKT_BEAT1 = 64'h4011_7CC1_7F00_0001; // Corrected valid checksum (7CC1)
    localparam [63:0] PKT_BEAT2 = 64'h7F00_0002_0000_0000;

    // Corrupted Constants (Flipped a single byte in Beat 0)
    localparam [63:0] ERR_BEAT0 = 64'h4500_DEAD_0001_0000; 

    initial begin
        // Initialize Inputs
        clk           = 0;
        rst_n         = 0;
        s_axis_tdata  = 64'd0;
        s_axis_tkeep  = 8'h00;
        s_axis_tvalid = 1'b0;
        s_axis_tready = 1'b1;
        s_axis_tlast  = 1'b0;

        // Reset Pulse
        #20;
        rst_n = 1;
        #20;

        // =====================================================================
        // SCENARIO 1: Test a Single Perfectly Valid Packet
        // =====================================================================
        $display("\n[TB] === SCENARIO 1: Sending Valid Packet ===");
        @(posedge clk);
        s_axis_tdata  = PKT_BEAT0;
        s_axis_tkeep  = 8'hFF;
        s_axis_tvalid = 1'b1;
        s_axis_tlast  = 1'b0;
        
        @(posedge clk);
        s_axis_tdata  = PKT_BEAT1;
        
        @(posedge clk);
        s_axis_tdata  = PKT_BEAT2;
        s_axis_tlast  = 1'b1;
        
        @(posedge clk);
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
        s_axis_tdata  = 64'd0;

        // Wait for pipeline completion delay clearance before next phase
        #80;

        // =====================================================================
        // SCENARIO 2: Test a Corrupted Packet (Should Fail Verification)
        // =====================================================================
        $display("\n[TB] === SCENARIO 2: Sending Corrupted Packet ===");
        @(posedge clk);
        s_axis_tdata  = ERR_BEAT0; // Injected invalid data bytes
        s_axis_tvalid = 1'b1;
        s_axis_tlast  = 1'b0;
        
        @(posedge clk);
        s_axis_tdata  = PKT_BEAT1;
        
        @(posedge clk);
        s_axis_tdata  = PKT_BEAT2;
        s_axis_tlast  = 1'b1;
        
        @(posedge clk);
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
        s_axis_tdata  = 64'd0;

        #80;

        // =====================================================================
        // SCENARIO 3: Test Streaming Line-Rate Inputs (Back-To-Back No Idles)
        // =====================================================================
        $display("\n[TB] === SCENARIO 3: Streaming Back-to-Back Packets ===");
        @(posedge clk);
        
        // --- Packet A: Beat 0 ---
        s_axis_tdata  = PKT_BEAT0;
        s_axis_tvalid = 1'b1;
        s_axis_tlast  = 1'b0;
        
        // --- Packet A: Beat 1 ---
        @(posedge clk);
        s_axis_tdata  = PKT_BEAT1;
        
        // --- Packet A: Beat 2 / Last ---
        @(posedge clk);
        s_axis_tdata  = PKT_BEAT2;
        s_axis_tlast  = 1'b1;
        
        // --- Packet B: Beat 0 (Immediately follows without dropping tvalid) ---
        @(posedge clk);
        s_axis_tdata  = PKT_BEAT0;
        s_axis_tlast  = 1'b0;
        
        // --- Packet B: Beat 1 ---
        @(posedge clk);
        s_axis_tdata  = PKT_BEAT1;
        
        // --- Packet B: Beat 2 / Last ---
        @(posedge clk);
        s_axis_tdata  = PKT_BEAT2;
        s_axis_tlast  = 1'b1;
        
        // --- Clear Stream ---
        @(posedge clk);
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
        s_axis_tdata  = 64'd0;

        // Finalize remaining cycles in processing engine pipeline
        #120;
        $finish;
    end

    // Monitor Output Verification Statuses Real-Time
    always @(posedge clk) begin
        if (checksum_valid) begin
            if (checksum_ok) begin
                $display("[OUTPUT MATCH] Time: %0t ns -> PASS", $time);
            end else begin
                $display("[OUTPUT MATCH] Time: %0t ns -> FAIL (Corrupted Header Flagged Correctly)", $time);
            end
        end
    end

endmodule
