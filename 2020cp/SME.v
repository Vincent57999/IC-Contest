module SME(
    input clk,
    input reset,
    input [7:0] chardata,
    input isstring,
    input ispattern,
    output valid,
    output reg match,
    output reg [4:0] match_index
);

    parameter [1:0] IDLE = 2'd0, READ = 2'd1, MATCH = 2'd2, DONE = 2'd3;
    reg [1:0] state,next_state;

    reg [7:0] str_memorey [33:0];//32+2頭尾
    reg [7:0] pat_memorey [7:0];
    reg [6:0] str_lenth;
    reg [4:0] pat_lenth;
    
    reg is_94;//有沒有 ^
    reg match_flag;
    reg match_success;
    reg [6:0] str_counter;
    reg [4:0] pat_counter;
    reg is_42;//有沒有 *
    reg [6:0] counter_42; //數 * 跳過了幾個
    reg [6:0] before_42; //進到 * 前過了幾個
    reg is_46_first; //有沒有 . 開頭
    reg [2:0] counter_46; //開頭有幾個 .

//-------------------------------------------------------------------------------

//valid
assign valid = (state == DONE);

//read str 
always @(posedge clk or posedge reset) begin
    if (next_state == IDLE) begin
        str_lenth <= 7'd1;
        str_memorey[0] <= 8'd32; //頭變成0
    end
    else if(next_state == READ && isstring == 1)begin
        str_memorey[str_lenth] = chardata;
        str_lenth = str_lenth + 7'd1;
    end
end
always @(posedge isstring) begin //新的str時重製
    str_lenth <= 7'd1;
end
always @(posedge (~isstring)) begin //str結束時在尾巴補0
    str_memorey[str_lenth] = 8'd32;
    str_lenth = str_lenth + 7'd1;
end

//read pat
always @(posedge clk or posedge reset) begin
    if (next_state == IDLE || next_state == DONE) begin
        pat_lenth <= 5'd0;
        is_94 <= 0;
    end
    else if(next_state == READ && ispattern == 1)begin
        if (chardata==8'd94 || chardata==8'd36) begin//^ 或是 $，將空格放入
            pat_memorey[pat_lenth] <= 8'd32 ;
            if (chardata==8'd94) begin //^ 要額外處理
                is_94 <= 1;
            end
        end 
        else begin
            pat_memorey[pat_lenth] <= chardata;
        end
        pat_lenth = pat_lenth + 5'd1;
    end
end

//match_flag
always @(posedge clk or posedge reset) begin
    if (state == IDLE || state == READ) begin
        match_flag <= 0;
        match_success <= 0;
        str_counter <= 0;
        pat_counter <= 0;
        is_42 <= 0;
        counter_42 <= 0;
        before_42 <= 0;
        is_46_first <= 0;
        counter_46 <= 0;
    end
    else if (next_state == MATCH) begin
        pat_memorey[pat_lenth] <= 0; //避免上次運算影響到下次
        if (match_flag == 0) begin
            if (pat_memorey[pat_counter] == 8'd42) begin // *
                is_42 <= 1;//確定有 *
                if ((pat_counter + 1) == pat_lenth) begin//假如星號在最後
                    match_flag <= 1;
                    match_success <= 1;
                end 
                else if (str_memorey[str_counter] == pat_memorey[pat_counter + 1]) begin//如果 * 的下一個有找到
                    pat_counter <= pat_counter + 2;
                end 
                else begin//星星的下個沒找到
                    pat_counter <= pat_counter;
                end
            end
            else if (pat_memorey[counter_46] == 8'd46) begin
                is_46_first <= 1;
                counter_46 <= counter_46 + 1;
            end
            else if (pat_memorey[pat_counter] == 8'd46) begin// .
                pat_counter <= pat_counter + 1;
            end
            else begin //正常
                if (str_memorey[str_counter] == pat_memorey[pat_counter]) begin
                    pat_counter <= pat_counter + 1;
                end 
                else if (pat_counter == pat_lenth) begin
                    pat_counter <= pat_counter;
                end
                else begin
                    if (is_46_first) begin
                        pat_counter <= counter_46;
                    end else begin
                        pat_counter <= 0;
                    end
                end
            end
        end

        str_counter = str_counter + 1;
        if (is_42 == 1) begin
            counter_42 <= counter_42 + 1;
        end

        if (str_counter == (str_lenth +1) || pat_counter == pat_lenth) begin
            match_flag <= 1;
            if (pat_counter == pat_lenth) begin
                match_success <= 1;
            end
        end
    end
end
always @(posedge is_42) begin //要算 * 前有幾個
    //if (str_memorey[str_counter] == pat_memorey[pat_counter + 1] && str_memorey[str_counter - 1] == pat_memorey[pat_counter - 1]) begin//如果 * 沒有跳過
    //     pat_counter <= pat_counter;
    //end
    if (str_memorey[str_counter-1] == pat_memorey[pat_counter - 1] && str_memorey[str_counter - 2] == pat_memorey[pat_counter - 3]) begin//str + 1, pat + 2之後，所以要減回去
        before_42 <= pat_counter - 2;
    end
    else begin
        before_42 <= pat_counter;
    end
end

//match
always @(posedge match_flag) begin
    if (match_success) begin
        match <= 1;
    end else begin
        match <= 0;
    end
end

//match_index
always @(posedge match_flag) begin
    if (is_94 && match_success) begin //^ 的例外
        match_index <= str_counter - pat_counter - 7'd1;
    end
    else if (is_42 && match_success) begin //* 的例外
        match_index <= str_counter - before_42 - counter_42 - 7'd2;
    end
    else if ((str_counter == pat_counter + 1) && match_success) begin //從頭都一樣的例外
        match_index <= 7'd0;
    end
    else if (match_success) begin
        match_index <= str_counter - pat_counter - 7'd2;
    end 
end


//---------------------------------------------------------------------------------

//state
always@(posedge clk or posedge reset)
begin
	if(reset) state <= IDLE;
	else state <= next_state;
end

always @(*) begin
    case (state)
        IDLE    :next_state <= reset ? IDLE : READ;
        READ    :next_state <= (ispattern == 1 || isstring == 1) ? READ : MATCH;
        MATCH   :next_state <= match_flag ? DONE : MATCH;
        DONE    :next_state <= READ;
        default :next_state <= IDLE;
    endcase
end
endmodule
