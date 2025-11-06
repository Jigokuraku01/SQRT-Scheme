module sqrt2 (
    inout wire [15:0] IO_DATA,
    output wire IS_NAN,
    output wire IS_PINF,
    output wire IS_NINF,
    output wire RESULT,
    input wire CLK,
    input wire ENABLE
  );

  reg [15:0] inp_data;
  reg [2:0] state;
  reg [21:0] mantissa_big;
  reg [9:0] ans_mantissa;
  reg ans_sign;
  reg [4:0] ans_exponent;
  reg [15:0] pos_result;
  reg [9:0] inp_mantissa;
  reg [4:0] inp_exp;

  reg [21:0] remainder;
  reg [10:0] root;
  reg [21:0] tmp_root;
  reg [3:0] sqrt_iter_cnt;

  reg [16:0] special_check;
  reg is_special;

  reg [15:0] out_data;
  assign IO_DATA = out_data;

  reg [2:0] Start = 3'd0;
  reg [2:0] Calculate = 3'd1;
  reg [2:0] Done = 3'd2;

  function automatic [26:0] prepare_mantissa_and_exponent;
    input [9:0] mant;
    input [4:0] exp;
    reg [9:0] ans_mant;
    reg [4:0] ans_exp;
    integer pos_of_last_one;
    integer i;
    begin
      ans_mant = 10'b0;
      ans_exp = 5'b0;
      pos_of_last_one = 0;
      if (exp != 0)
      begin
        ans_exp  = (exp + 15) >> 1;
        ans_mant = mant | 10'b1000000000;
        if (exp[0] == 0)
          ans_mant = ans_mant << 1;
      end
      else
      begin
        for (i = 9; i >= 0; i = i - 1)
        begin
          if (mant[i] == 1'b1)
          begin
            pos_of_last_one = i + 1;
            i = -1;
          end
        end
        ans_exp  = (pos_of_last_one + 5) >> 1;
        ans_mant = mant << (11 - pos_of_last_one);
        if (pos_of_last_one[0] == 0)
          ans_mant = ans_mant << 1;
      end
      ans_mant = ans_mant << 10;
      prepare_mantissa_and_exponent = {ans_mant, ans_exp};
    end
  endfunction

  function automatic [16:0] check_special_cases;
    input [15:0] data;
    reg sign;
    reg [4:0] exp;
    reg [9:0] mant;
    reg is_special;
    reg [15:0] result_val;
    reg [15:0] quietNan;
    begin
      quietNan = 16'hFE00;
      sign = data[15];
      exp = data[14:10];
      mant = data[9:0];
      is_special = 0;
      result_val = 16'h0000;

      if (exp == 5'h1F)
      begin
        is_special = 1;
        if (mant == 0)
          result_val = (sign == 0) ? data : quietNan;
        else
          result_val = data;
      end
      else if (exp == 0 && mant == 0)
      begin
        is_special = 1;
        result_val = data;
      end
      else if (sign == 1)
      begin
        is_special = 1;
        result_val = quietNan;
      end

      check_special_cases = {is_special, result_val};
    end
  endfunction

  always @(posedge CLK)
  begin
    if (sqrt_iter_cnt > 2)
    begin
      ans_mantissa = root[9:0];
      out_data     = {ans_sign, ans_exponent, ans_mantissa};
    end
  end
  always @(negedge CLK)
  begin
    if (!ENABLE)
    begin
      state         = Start;
      RESULT        = 0;
      IS_NAN        = 0;
      IS_PINF       = 0;
      IS_NINF       = 0;
      sqrt_iter_cnt = 0;
      root          = 0;
      remainder     = 0;
      tmp_root      = 0;
      ans_mantissa  = 0;
      ans_sign      = 0;
      ans_exponent  = 0;
      pos_result    = 0;
      inp_data      = 0;
      inp_mantissa  = 0;
      inp_exp       = 0;
      mantissa_big  = 0;
      out_data      = 16'bz;
    end
    else
    begin
      case (state)
        Start:
        begin
          inp_data      = IO_DATA;
          inp_exp       = IO_DATA[14:10];
          inp_mantissa  = IO_DATA[9:0];

          special_check = check_special_cases(inp_data);
          is_special    = special_check[16];
          pos_result    = special_check[15:0];

          if (is_special)
          begin
            ans_sign = inp_data[15];
            ans_exponent = pos_result[14:10];
            ans_mantissa = pos_result[9:0];
            out_data = pos_result;
            RESULT = 1;
            IS_NAN       = (pos_result[14:10] == 5'h1F && pos_result[9:0] != 0) ||
            (pos_result[15] && (pos_result[14:10] != 0 || pos_result[9:0] != 0));
            IS_PINF = (pos_result[14:10] == 5'h1F && pos_result[9:0] == 0 && !pos_result[15]);
            IS_NINF = 0;
            state = Done;
          end
          else
          begin
            ans_sign                     = 0;
            {mantissa_big, ans_exponent} = prepare_mantissa_and_exponent(inp_mantissa, inp_exp);
            root                         = 0;
            remainder                    = 0;
            sqrt_iter_cnt                = 0;
            ans_mantissa                 = root[9:0];
            out_data                     = {ans_sign, ans_exponent, ans_mantissa};
            state                        = Calculate;
          end
        end

        Calculate:
        begin
          if (sqrt_iter_cnt == 12)
          begin
            state  = Done;
            RESULT = 1;
          end
          else
          begin
            tmp_root = (root << 2) | 1;
            if (tmp_root <= (remainder << 2 | mantissa_big[21:20]))
            begin
              root      = (root << 1) | 1;
              remainder = (remainder << 2 | mantissa_big[21:20]) - tmp_root;
            end
            else
            begin
              root      = root << 1;
              remainder = (remainder << 2 | mantissa_big[21:20]);
            end
            mantissa_big  = mantissa_big << 2;
            sqrt_iter_cnt = sqrt_iter_cnt + 1;

            if (sqrt_iter_cnt <= 2)
            begin
              ans_mantissa = root[9:0];
              if (sqrt_iter_cnt <= 2)
              begin
                out_data = {ans_sign, ans_exponent, ans_mantissa};
              end
            end
          end
        end

        Done:
        begin
          RESULT = 1;
        end
      endcase
    end
  end

endmodule
