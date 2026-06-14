`default_nettype none
// this module is purely combinational. clk/rst_n are included for optional output registering only.

module decoder #(

    parameter DATA_W = 64
)(
    input  logic          clk,
    input  logic        rst_n,

    // input from descrambler
    input  logic                      i_valid,       // block is valid from descrambler
    input  logic [DATA_W + 1 : 0]      i_data,        // 64 bit descrambled payload + 2 bit sync header

    // output to MAC 
    output logic                      o_valid,
    output logic [DATA_W - 1 : 0]      o_data,        // 8 bytes of XGMII data
    output logic [DATA_W/8 - 1 : 0]    o_ctrl,        // 8 flags of: 1 = control character, 0 = data character (per byte)
    output logic [DATA_W/8 - 1 : 0]    o_keep,        // 8 flags clarifying valid bytes in this beat (only meaningful on terminate blocks)
    output logic                      o_start,       // "this beat contains a Start character"
    output logic                       o_idle,        // "all 8 bytes are Idle"
    output logic                  o_terminate,   // "this beat contains a Terminate character"
    output logic                      o_error        // invalid sync header OR unrecognized block type
);

   
    localparam BLOCK_TYPE_W = 8;

    // block type codes from IEEE 802.3 clause 49 figure 49-7

    localparam [BLOCK_TYPE_W-1:0]
        BLOCK_TYPE_CTRL     = 8'h1e,
        BLOCK_TYPE_OS_4     = 8'h2d,
        BLOCK_TYPE_START_4  = 8'h33,
        BLOCK_TYPE_OS_04    = 8'h55,
        BLOCK_TYPE_OS_START = 8'h66,
        BLOCK_TYPE_START_0  = 8'h78,
        BLOCK_TYPE_OS_0     = 8'h4b,
        BLOCK_TYPE_TERM_0   = 8'h87,
        BLOCK_TYPE_TERM_1   = 8'h99,
        BLOCK_TYPE_TERM_2   = 8'haa,
        BLOCK_TYPE_TERM_3   = 8'hb4,
        BLOCK_TYPE_TERM_4   = 8'hcc,
        BLOCK_TYPE_TERM_5   = 8'hd2,
        BLOCK_TYPE_TERM_6   = 8'he1,
        BLOCK_TYPE_TERM_7   = 8'hff;


    // separate sync header from payload and validate sync header isn't 00 or 11, assert o_error accordingly. hint: XOR!
    // for data blocks (sync = 01): pass payload through, set keep = 8'hFF
    // for control blocks (sync = 10): case statement on block_type field
    // set o_idle, o_start, o_terminate, o_error based on which type matches
    // compute o_keep for terminate blocks. hint: lookup one-hot subtract trick

    // * accounot for all possible scenarios where you should assert o_error
         

endmodule
