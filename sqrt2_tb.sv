`include "sqrt2.sv"

module sqrt2_tb;
  reg CLK;
  reg ENABLE;
  reg  [15:0] IO_DATA_reg;
  reg should_be_inp;
  wire [15:0] IO_DATA_wire;
  wire IS_NAN_wire;
  wire IS_PINF_wire;
  wire IS_NINF_wire;
  wire RESULT_wire;

  assign IO_DATA_wire = should_be_inp ? IO_DATA_reg : 16'bz;
  integer fd;
  sqrt2 cur_sheme (
          .IO_DATA(IO_DATA_wire),
          .IS_NAN(IS_NAN_wire),
          .IS_PINF(IS_PINF_wire),
          .IS_NINF(IS_NINF_wire),
          .RESULT(RESULT_wire),
          .CLK(CLK),
          .ENABLE(ENABLE)
        );

  reg [15:0] exp_results [0:6];
  reg [15:0] inp_tests [0:6];
  integer i;
  initial
  begin
    inp_tests[0] = 16'h4800;
    exp_results[0] = 16'h4000;

    inp_tests[1] = 16'h3400;
    exp_results[1] = 16'h3800;

    inp_tests[2] = 16'hBC00;
    exp_results[2] = 16'hFE00;

    inp_tests[3] = 16'hFE00;
    exp_results[3] = 16'hFE00;

    inp_tests[4] = 16'h7C00;
    exp_results[4] = 16'h7C00;

    inp_tests[5] = 16'h0000;
    exp_results[5] = 16'h0000;

    inp_tests[6] = 16'h3C00;
    exp_results[6] = 16'h3C00;
  end

  always #1 CLK = ~CLK;

  always @(CLK)
  begin
    $fstrobe(fd, "%d\t%b", $time, CLK);
  end

  initial
  begin
    CLK = 0;
    fd = $fopen("sqrt2_log.csv", "w");

    ENABLE = 0;
    should_be_inp = 0;
    IO_DATA_reg = 16'bz;
    for(i = 0; i < 7; ++i)
    begin
      #2;
      begin
        $fdisplay(fd,"Test %0d. Input: %h, Expected Ans: %h", i, inp_tests[i], exp_results[i]);
        $display("Test %0d. Input: %h, Expected Ans: %h", i, inp_tests[i], exp_results[i]);
        should_be_inp = 1;
        IO_DATA_reg = inp_tests[i];
        ENABLE = 0;
        #2;
        ENABLE = 1;
        #2;
        should_be_inp = 0;
        IO_DATA_reg = 16'bz;
        wait(RESULT_wire === 1'b1);
        #2;
        if(IO_DATA_wire === exp_results[i])
        begin
          $fdisplay(fd, "Test %0d PASSED. Got: %h", i, IO_DATA_wire);
          $display("Test %0d PASSED. Got: %h", i, IO_DATA_wire);
        end
        else
        begin
          $display(fd, "Test %0d FAILED. Got: %h", i, IO_DATA_wire);
          $display("Test %0d FAILED. Got: %h", i, IO_DATA_wire);
        end

        #2;
        ENABLE = 0;
        #2;
        $fdisplay(fd, "");
        $display("");
      end
    end
    #2;
    $fclose(fd);
    $finish;
  end
endmodule
