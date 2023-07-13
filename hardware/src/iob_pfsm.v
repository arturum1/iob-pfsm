`timescale 1ns/1ps

`include "iob_lib.vh"
`include "iob_pfsm_conf.vh"
`include "iob_pfsm_swreg_def.vh"

`define IOB_PFSM_CEIL_DIV(A, B) (A % B == 0 ? (A / B) : ((A/B) + 1))

module iob_pfsm # (
   `include "iob_pfsm_params.vs"
  ) (
   `include "iob_pfsm_io.vs"
  );

   //Dummy iob_ready_nxt_o and iob_rvalid_nxt_o to be used in swreg (unused ports)
   wire iob_ready_nxt_o;
   wire iob_rvalid_nxt_o;

  //BLOCK Register File & Configuration control and status register file.
  `include "iob_pfsm_swreg_inst.vs"

  // Keep track of current PFSM state
  wire [STATE_W-1:0] next_state, current_state;
  iob_reg_r #(
    .DATA_W (STATE_W),
    .RST_VAL(1'b0)
  ) state_reg (
    .clk_i(clk_i),
    .cke_i(cke_i),
    .arst_i(arst_i),
    .rst_i(SOFTRESET),
    .data_i(next_state),
    .data_o(current_state)
  );

  assign CURRENT_STATE = current_state;

  // Number of bytes in IOb-Native data bus
  localparam N_BYTES_DATA_WORD = `IOB_PFSM_CEIL_DIV(DATA_W,8);
  // Number of bytes in each LUT memory word
  localparam LUT_DATA_W = STATE_W+OUTPUT_W;
  // Number of bits to shift for word select
  localparam WORD_SELECT_SHIFT = N_BYTES_DATA_WORD*MEM_WORD_SELECT;

  wire [LUT_DATA_W-1:0] lut_o;
  // LUT data input signal. Composed of same bits as currently in LUT joined by new DATA_W bits.
  wire [LUT_DATA_W-1:0] lut_data_input = lut_o[LUT_DATA_W-1:WORD_SELECT_SHIFT+DATA_W] | iob_wdata_i<<(WORD_SELECT_SHIFT) | lut_o[0+:WORD_SELECT_SHIFT];
  // LUT address. Either memory address corresponding to:
  //  1) curent_state, input_combination
  //  2) Selected memory address for writing
  wire [INPUT_W+STATE_W-1:0] lut_addr = MEMORY_wen ? (iob_addr_i-`IOB_PFSM_MEMORY_ADDR)>>$clog2(N_BYTES_DATA_WORD) : {current_state,input_ports};

 // Memory used as LUT for PFSM states
 iob_regfile_sp #(
    .DATA_W(STATE_W+OUTPUT_W),
    .ADDR_W(INPUT_W+STATE_W)
 ) lut (
    .clk_i(clk_i),
    .cke_i(cke_i),
    .arst_i(arst_i),
    .rst_i(1'b0),
    .we_i(MEMORY_wen),
    .addr_i(lut_addr),
    .d_i(lut_data_input),
    .d_o(lut_o)
 );

 // Extract bits from word of `lut_o`
 assign output_ports = lut_o[0+:OUTPUT_W]; // Least significant bits connected to output
 assign next_state = lut_o[OUTPUT_W+:STATE_W]; // Followed by next_state bits

endmodule