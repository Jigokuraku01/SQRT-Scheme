module sqrt2 (
    input wire [15:0] IO_DATA,
    output reg IS_NAN,
    output reg IS_PINF,
    output reg IS_NINF,
    output reg RESULT,
    input wire CLK,
    input wire ENABLE
  );

  reg [15:0] inp_data;
  reg [2:0] state;
  reg [21:0] mantissa_big;
  reg [9:0] ans_mantissa;
  reg ans_sign;
  reg [4:0] ans_exponent;
  reg calculation_done;
  reg [15:0] pos_result;
  reg [9:0] inp_mantissa;
  reg [4:0] inp_exp;

  localparam [2:0] Start = 3'd0;
  localparam [2:0] Calculate = 3'd1;
  localparam [2:0] Done = 3'd2;

  reg [21:0] remainder;
  reg [10:0] root;
  ref [21:0] tmp_root;
  integer sqrt_iter_cnt;


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
        begin
          ans_mant = ans_mant << 1;
        end
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

        ans_exp  = (pos_of_last_one + 6) >> 1;
        ans_mant = mant << (11 - pos_of_last_one);
        if (pos_of_last_one[0] == 0)
        begin
          ans_mant = ans_mant << 1;
        end
      end
      ans_mant <<= 10;
      prepare_mantissa_and_exponent = {ans_exp, ans_mant};
    end
  endfunction

  function automatic [16:0] check_special_cases;
    input [15:0] data;
    reg sign;
    reg [4:0] exp;
    reg [9:0] mant;
    reg is_special;
    reg [15:0] result_val;
    reg [15:0] quietNan = 16'hFE00;
    begin
      is_special = 0;
      result_val = 16'h0000;
      sign = data[15];
      exp = data[14:10];
      mant = data[9:0];

      if (exp == 5'h1F)
      begin
        is_special = 1;
        if (mant == 0)
        begin  // INF
          if (sign == 0)
          begin  // +INF
            result_val = data;
          end
          else
          begin  // -INF
            result_val = quietNan;  // -INF
          end
        end
        else
        begin  // NAN
          result_val = data;
        end
      end
      else if (exp == 0 && mant == 0)
      begin  // ZERO
        is_special = 1;
        result_val = data;
      end
      else if (sign == 1)
      begin  // NEG
        is_special = 1;
        result_val = quietNan;
      end

      check_special_cases = {is_special, result_val};
    end
  endfunction


  always @(posedge CLK)
  begin
    if (!ENABLE)
    begin
      state = Start;
      RESULT = 0;
      IS_NAN = 0;
      IS_PINF = 0;
      IS_NINF = 0;
      calculation_done = 0;
      sqrt_iter_cnt = 0;
    end
    else
    begin
      if(calculation_done == 1 && state == Done)
      begin
        IO_DATA = {ans_sign, ans_exponent, ans_mantissa};
      end
      else if(sqrt_iter_cnt < 11 && state == Calculate)
      begin
        sqrt_iter_cnt <= sqrt_iter_cnt + 1;
      end
      case (state)
        Start:
        begin
          inp_data = IO_DATA;
          inp_exp = IO_DATA[14:10];
          inp_mantissa = IO_DATA[9:0];

          begin
            reg [16:0] special_check;
            reg is_special;
            special_check = check_special_cases(inp_data);
            is_special = special_check[16];
            pos_result = special_check[15:0];

            if (is_special)
            begin
              calculation_done = 1;
              state = Done;
              RESULT = 1;
              ans_sign = pos_result[15];
              ans_exponent = pos_result[14:10];
              ans_mantissa = pos_result[9:0];


              IS_NAN = (pos_result[14:10] == 5'h1F && pos_result[9:0] != 0) ||
              (pos_result[15] && (pos_result[14:10] != 0 || pos_result[9:0] != 0));
              IS_PINF = (pos_result[14:10] == 5'h1F && pos_result[9:0] == 0 && !pos_result[15]);
              IS_NINF = 0;

            end
            else
            begin
              ans_sign = 0;
              {ans_exponent, mantissa_big} = prepare_mantissa_and_exponent(inp_mantissa, inp_exp);

              sqrt_iter_cnt = 0;
              remainder = 0;
              root = 0;
              tmp_root = 0;

              RESULT = 0;
              state = Calculate;
              IS_NAN = 0;
              IS_PINF = 0;
              IS_NINF = 0;
            end
          end
        end

        Calculate:
        begin
          if(sqrt_iter_cnt == 11)
          begin
            state = Done;
            calculation_done = 1;
          end
          else if (sqrt_iter_cnt == 1)
          begin
            root = 1;
            remainder = mantissa_big[21:20] - 1;
          end
          else
          begin
            tmp_root = (root << 2) | 1;
            if(tmp_root <= (remainder << 2 | mantissa_big[21 - 2 * sqrt_iter_cnt : 20 - 2 * sqrt_iter_cnt]))
            begin
              root = root << 1 | 1;
              remainder = (remainder << 2 | mantissa_big[21 - 2 * sqrt_iter_cnt : 20 - 2 * sqrt_iter_cnt]) - tmp_root;
            end
            else
            begin
              root = root << 1;
              remainder = (remainder << 2 | mantissa_big[21 - 2 * sqrt_iter_cnt : 20 - 2 * sqrt_iter_cnt]);
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
