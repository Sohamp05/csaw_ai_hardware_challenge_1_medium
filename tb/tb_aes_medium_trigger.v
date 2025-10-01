//======================================================================
//
// tb_aes_medium_trigger.v
// -----------------------
// Focused testbench to demonstrate latent ciphertext behaviour using
// the diagnostic seed in the AES medium challenge design.
//
//======================================================================

`default_nettype none

module tb_aes_medium_trigger;
  //----------------------------------------------------------------
  // Parameters and local constants.
  //----------------------------------------------------------------
  localparam CLK_HALF_PERIOD = 1;
  localparam CLK_PERIOD      = 2 * CLK_HALF_PERIOD;

  localparam ADDR_CTRL       = 8'h08;
  localparam ADDR_STATUS     = 8'h09;
  localparam ADDR_CONFIG     = 8'h0a;
  localparam ADDR_KEY0       = 8'h10;
  localparam ADDR_KEY1       = 8'h11;
  localparam ADDR_KEY2       = 8'h12;
  localparam ADDR_KEY3       = 8'h13;
  localparam ADDR_KEY4       = 8'h14;
  localparam ADDR_KEY5       = 8'h15;
  localparam ADDR_KEY6       = 8'h16;
  localparam ADDR_KEY7       = 8'h17;
  localparam ADDR_BLOCK0     = 8'h20;
  localparam ADDR_BLOCK1     = 8'h21;
  localparam ADDR_BLOCK2     = 8'h22;
  localparam ADDR_BLOCK3     = 8'h23;
  localparam ADDR_RESULT0    = 8'h30;
  localparam ADDR_RESULT1    = 8'h31;
  localparam ADDR_RESULT2    = 8'h32;
  localparam ADDR_RESULT3    = 8'h33;

  localparam [255:0] TARGET_KEY = {
    128'hdeadbeef0123456789abcdef0a1b2c3d,
    128'h00000000000000000000000000000000
  };

  //----------------------------------------------------------------
  // Testbench signals.
  //----------------------------------------------------------------
  reg           tb_clk;
  reg           tb_reset_n;
  reg           tb_cs;
  reg           tb_we;
  reg  [7 : 0]  tb_address;
  reg  [31 : 0] tb_write_data;
  wire [31 : 0] tb_read_data;

  reg  [31 : 0] captured_word;
  reg  [127:0]  first_plaintext;
  reg  [127:0]  second_plaintext;
  reg  [127:0]  first_result;
  reg  [127:0]  second_result;


  //----------------------------------------------------------------
  // Device under test.
  //----------------------------------------------------------------
  aes dut (
    .clk(tb_clk),
    .reset_n(tb_reset_n),
    .cs(tb_cs),
    .we(tb_we),
    .address(tb_address),
    .write_data(tb_write_data),
    .read_data(tb_read_data)
  );


  //----------------------------------------------------------------
  // Clock generator.
  //----------------------------------------------------------------
  always begin
    #(CLK_HALF_PERIOD);
    tb_clk = ~tb_clk;
  end


  //----------------------------------------------------------------
  // Primitive bus helpers.
  //----------------------------------------------------------------
  task automatic write_word(input [7:0] addr, input [31:0] data);
    begin
      tb_address    = addr;
      tb_write_data = data;
      tb_cs         = 1'b1;
      tb_we         = 1'b1;
      #(CLK_PERIOD);
      tb_cs         = 1'b0;
      tb_we         = 1'b0;
    end
  endtask

  task automatic read_word(input [7:0] addr);
    begin
      tb_address = addr;
      tb_cs      = 1'b1;
      tb_we      = 1'b0;
      #(CLK_PERIOD);
      captured_word = tb_read_data;
      tb_cs      = 1'b0;
    end
  endtask

  task automatic write_block(input [127:0] block);
    begin
      write_word(ADDR_BLOCK0, block[127:96]);
      write_word(ADDR_BLOCK1, block[95:64]);
      write_word(ADDR_BLOCK2, block[63:32]);
      write_word(ADDR_BLOCK3, block[31:0]);
    end
  endtask

  task automatic write_key128(input [127:0] key_value);
    begin
      write_word(ADDR_KEY0, key_value[127:96]);
      write_word(ADDR_KEY1, key_value[95:64]);
      write_word(ADDR_KEY2, key_value[63:32]);
      write_word(ADDR_KEY3, key_value[31:0]);
      // Clear remaining locations for determinism.
      write_word(ADDR_KEY4, 32'h0);
      write_word(ADDR_KEY5, 32'h0);
      write_word(ADDR_KEY6, 32'h0);
      write_word(ADDR_KEY7, 32'h0);
    end
  endtask

  task automatic trigger_init(input bit keylen128);
    begin
      write_word(ADDR_CONFIG, {28'h0, keylen128 ? 4'h2 : 4'h0});
      write_word(ADDR_CTRL, 32'h1);
    end
  endtask

  task automatic start_encrypt(input bit keylen128);
    begin
      write_word(ADDR_CONFIG, {28'h0, (keylen128 ? 4'h2 : 4'h0) | 4'h1});
      write_word(ADDR_CTRL, 32'h2);
    end
  endtask

  task automatic wait_ready;
    begin
      repeat (40) begin
        read_word(ADDR_STATUS);
        if (captured_word[0])
          disable wait_ready;
        #(CLK_PERIOD);
      end
    end
  endtask

  task automatic wait_valid;
    begin
      repeat (40) begin
        read_word(ADDR_STATUS);
        if (captured_word[1])
          disable wait_valid;
        #(CLK_PERIOD);
      end
    end
  endtask

  task automatic read_result(output [127:0] block);
    begin
      read_word(ADDR_RESULT0); block[127:96] = captured_word;
      read_word(ADDR_RESULT1); block[95:64]  = captured_word;
      read_word(ADDR_RESULT2); block[63:32]  = captured_word;
      read_word(ADDR_RESULT3); block[31:0]   = captured_word;
    end
  endtask

  //----------------------------------------------------------------
  // Stimulus.
  //----------------------------------------------------------------
  initial begin
    tb_clk       = 1'b0;
    tb_reset_n   = 1'b0;
    tb_cs        = 1'b0;
    tb_we        = 1'b0;
    tb_address   = 8'h00;
    tb_write_data= 32'h0;
    first_plaintext  = 128'h00112233445566778899aabbccddee00;
    second_plaintext = 128'h102132435465768798a9babbdcddfe0f;
    first_result     = 128'h0;
    second_result    = 128'h0;

    #(5 * CLK_PERIOD);
    tb_reset_n = 1'b1;

    // Load trigger key and initialise key schedule.
    write_key128(TARGET_KEY[255:128]);
    trigger_init(1'b0);
    wait_ready;

    // First encryption - baseline ciphertext capture.
    write_block(first_plaintext);
    start_encrypt(1'b0);
    wait_valid;
    wait_ready;
    read_result(first_result);
    $display("First ciphertext (should be honest AES): %032x", first_result);

    // Second encryption should echo previous plaintext once diagnostics engage.
    write_block(second_plaintext);
    start_encrypt(1'b0);
    wait_valid;
    wait_ready;
    read_result(second_result);

    $display("Second ciphertext: %032x", second_result);
    $display("Previous plaintext: %032x", first_plaintext);

    if (second_result === first_plaintext)
      $display("*** Observed ciphertext reuse of prior plaintext as designed.");
    else
      $display("*** Unexpected behaviour: ciphertext mismatch.");

    $finish;
  end
endmodule

`default_nettype wire
