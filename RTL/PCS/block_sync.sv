`default_nettype none

module block_sync_rx #(

    parameter HEAD_W = 2
)(
    input  logic          clk,
    input  logic        rst_n,

    // from GTY SerDes (directly, same signal also goes to gearbox)

    input  logic                i_serdes_v,   // serdes data is valid (CDR locked)

    // from gearbox
    input  logic                   i_valid,   // gearbox has a valid 66-bit block ready this cycle (flag to read header)
    input  logic [HEAD_W - 1 : 0]   i_head,   // 2-bit sync header to check

    // to gearbox
    output logic                    o_slip,   // tell gearbox to shift alignment by 1 bit

    // status
    output logic                    o_lock    // alignment found and confirmed
);

    // this module acts as a simple state machine, taking sync headers from the
    // gearbox and evaluating alignment accuracy.

    logic [6: 0] counter; //Count 64 valid header

    logic [4: 0] bad_header_count; //Count Invalid Headers
    logic [5: 0] good_header_count; //Count Valid Headers
  

    logic [HEAD_W - 1 : 0] header;   // 2-bit sync header to check

    typedef enum logic [1 : 0]{
        LOCK_LOST = 2'b00,
        BLOCK_LOCK = 2'b01
    } state;

    state current_state, next_state;

    always_ff @(posedge clk) begin
        if (rst_n) begin // If not reset
            if(!i_serdes_v) begin  //If serdes does not send active frames
                current_state <= LOCK_LOST; 
                counter <= 7'b0;
                good_header_count <= 6'b0;
                bad_header_count <= 5'b0;
                o_lock <= 1'b0;
            end else if (i_valid) begin //If there is a valid 66 bit block ready
                current_state <= next_state;
                o_lock <= (next_state == BLOCK_LOCK);

                if (current_state == BLOCK_LOCK) begin //Count good vs bad headers when in BLOCK_LOCK state
                    if(good_next + bad_next == 7'd64) begin
                        good_header_count <= 6'b0;
                        bad_header_count <= 5'b0;
                    end else begin
                        good_header_count <= good_next;
                        bad_header_count <= bad_next;
                    end
                end

                if (current_state == BLOCK_LOCK && next_state == LOCK_LOST) begin //During trasition between states
                    good_header_count <= 6'b0;
                    bad_header_count <= 5'b0;
                    counter <= 7'b0;
                end else if (header[1] ^ header[0]) begin //If header is valid
                    counter <= counter + 1;
                end else begin //Reset counter
                    counter <= 7'b0;
                end

            end else begin
                
            end

        end else begin // If reset
            o_lock <= 1'b0;
            current_state <= LOCK_LOST;
            counter <= 7'b0;
            good_header_count <= 6'b0;
            bad_header_count <= 5'b0;
        end
    end

    logic [5: 0] good_next;
    logic [4: 0] bad_next;

    always_comb begin
        o_slip = 1'b0;
        next_state = current_state;
        header = i_head;
        good_next = good_header_count + (header[1] ^ header[0]);
        bad_next = bad_header_count + !(header[1] ^ header[0]);
        case (current_state)
            LOCK_LOST: begin
                if ((header[1] ^ header[0]) && counter == 7'h3F) begin //Previous 63 headers valid and 64th also valid so change state
                    next_state = BLOCK_LOCK;
                end else if (!(header[1] ^ header[0]) && i_valid) begin //If bad header, assert o_slip
                    o_slip = 1'b1;
                end
            end
            BLOCK_LOCK: begin
                if(bad_next > 5'd16) begin //If bad headers greater than 15
                    next_state = LOCK_LOST;
                    o_slip = 1'b1;
                end
            end
            default: next_state = LOCK_LOST; //Always default back to LOST_LOCK state
        endcase
        
    end

   

    /* once serdes data is valid (i_signal_ok from serdes) and gearbox has valid headers to share 
        (i_valid from gearbox_rx), start checking headers and counting:
        we expect to see valid headers (01 or 10) 64 times in a row.
        if at any point we see an invalid header (00 or 11), assert o_slip and reset. 
        
        This function brute forces an alignment search until we find the correct offset and lock. 
        We maintain lock until reset or signal loss. any further errors downstream (invalid block types, corrupted data) are handled by the decoder. */
  
    // * hint: header validation is a single XOR.


endmodule