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

    logic [6: 0] counter;

    logic [4: 0] invalid_header;

    logic [1 : 0] header;   // 2-bit sync header to check

    typedef enum logic [1 : 0]{
        LOCK_LOST = 2'b00,
        BLOCK_LOCK = 2'b01
    } state;

    state current_state, next_state;

    always_ff @(posedge clk) begin
        if (rst_n) begin
            if(!i_serdes_v) begin
                current_state <= LOCK_LOST;
                counter <= 7'b0;
                invalid_header <= 5'b0;
                o_lock <= 1'b0;
            end else if (i_valid) begin
                current_state <= next_state;
                o_lock <= (next_state == BLOCK_LOCK);

                if (current_state == BLOCK_LOCK 
                    && next_state == LOCK_LOST) begin
                    invalid_header <= 5'b0;
                    counter <= 7'b0;
                    end else if (header[1] ^ header[0]) begin
                        counter <= counter + 1;
                end else begin
                    counter <= 7'b0;
                    if(current_state == BLOCK_LOCK) begin
                        invalid_header <= invalid_header + 1;
                    end
                end

            end else begin
                
            end

        end else begin
            o_lock <= 1'b0;
            current_state <= LOCK_LOST;
            counter <= 7'b0;
            invalid_header <= 5'b0;
        end
    end

    always_comb begin
        o_slip = 1'b0;
        next_state = current_state;
        header = i_head;
        case (current_state)
            LOCK_LOST: begin
                if (counter == 7'h40) begin 
                    next_state = BLOCK_LOCK;
                end else if (!(header[1] ^ header[0])) begin
                    o_slip = 1'b1;
                end
            end
            BLOCK_LOCK: begin
                if(invalid_header > 4'b1111) begin
                    next_state = LOCK_LOST;
                    o_slip = 1'b1;
                end
            end
            default: next_state = LOCK_LOST;
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