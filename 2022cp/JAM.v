module JAM (
    input CLK,
    input RST,
    output reg [2:0] W,
    output reg [2:0] J,
    input [6:0] Cost,
    output reg [3:0] MatchCount,
    output reg [9:0] MinCost,
    output Valid
);

    reg [2:0] n [0:7]; 
    reg [3:0] add_counter;
    reg [9:0] sum;
    reg [2:0] change_point;
    reg [2:0] bigger_point;
    reg [3:0] temp;
    reg bigger_found; //找到更大的


    parameter [2:0] IDLE = 4'd1 , DELAY = 4'd2 , ADDER = 4'd3 , CHANGE_POINT = 4'd4 , FIND_BIG = 4'd5 , SORT = 4'd6 , DONE = 4'd7;
    reg [2:0] state , next_state;
    

    reg sort_counter ;
    //n CHANGE
    always @(posedge CLK ) begin
        if(state == ADDER ) begin
            sort_counter <= 2'd0;
        end
        else if(state == IDLE) begin
            n[0] <= 3'd0;
            n[1] <= 3'd1;
            n[2] <= 3'd2;
            n[3] <= 3'd3;
            n[4] <= 3'd4;
            n[5] <= 3'd5;
            n[6] <= 3'd6;
            n[7] <= 3'd7;
            sort_counter <= 0;
        end
        else if(state == SORT) begin
            if(sort_counter == 0) begin
                n[bigger_point] <= n[change_point];
                n[change_point] <= n[bigger_point];
                sort_counter <= sort_counter + 1;
            end
            else if (sort_counter == 1) begin
                case (change_point)
                    3'd5 : begin
                        n[6] <= n[7];
                        n[7] <= n[6];
                    end
                    3'd4 : begin
                        n[5] <= n[7];
                        n[7] <= n[5];
                    end
                    3'd3 : begin
                        n[4] <= n[7];
                        n[7] <= n[4];
                        n[5] <= n[6];
                        n[6] <= n[5];
                    end
                    3'd2 : begin
                        n[3] <= n[7];
                        n[7] <= n[3];
                        n[4] <= n[6];
                        n[6] <= n[4];
                    end
                    3'd1 : begin
                        n[2] <= n[7];
                        n[7] <= n[2];
                        n[3] <= n[6];
                        n[6] <= n[3];
                        n[4] <= n[5];
                        n[5] <= n[4];
                    end
                    3'd0 : begin
                        n[1] <= n[7];
                        n[7] <= n[1];
                        n[2] <= n[6];
                        n[6] <= n[2];
                        n[3] <= n[5];
                        n[5] <= n[3];
                    end
                endcase
                sort_counter <= 1;
            end
        end
    end

    // change_point
    always @(posedge CLK ) begin
        if(state == IDLE) change_point <= 3'd0;
        else if(next_state == CHANGE_POINT) begin
            if(n[7] > n[6]) change_point <= 3'd6;
            else if(n[6] > n[5]) change_point <= 3'd5;
            else if(n[5] > n[4]) change_point <= 3'd4;
            else if(n[4] > n[3]) change_point <= 3'd3;
            else if(n[3] > n[2]) change_point <= 3'd2;
            else if(n[2] > n[1]) change_point <= 3'd1;
            else if(n[1] > n[0]) change_point <= 3'd0;
            else change_point <= 3'd7;
        end
    end


    //bigger_point
    always @(posedge CLK ) begin
        if(state == IDLE || state == ADDER) begin
            bigger_point <= 3'd0;
            bigger_found <= 0;
        end
        else if (state == CHANGE_POINT) begin
            bigger_point <= change_point + 1; // 預設最小比 change_point 大的數
            temp <= change_point + 2;
        end
        else if(state == FIND_BIG) begin
            if(change_point == 3'd6) begin
                bigger_point <= 3'd7;
                bigger_found <= 1;
            end
            else if (change_point == 3'd5) begin
                if ( n[7]<n[6] && n[7]>n[5] ) begin
                    bigger_point <= 3'd7;
                    bigger_found <= 1;
                end
                else begin
                    bigger_point <= 3'd6;
                    bigger_found <= 1;
                end
            end
            else begin
                if (temp <= 7) begin
                    if (n[temp] > n[change_point] && n[temp] < n[bigger_point]) begin
                        bigger_point <= temp;
                    end
                    temp = temp + 1;
                end
                else bigger_found <= 1;
            end
        end
    end


    //add_counter
    always @(posedge CLK) begin
        if(state == IDLE ) add_counter <= 3'd0;
        else if(state == ADDER) begin
            add_counter <= add_counter + 1'd1;
        end
        else if(state == CHANGE_POINT) add_counter <= 3'd0;
        else;
    end


    //讀取W snd J
    always @(add_counter) begin
        W = add_counter;
        J = n[add_counter];
    end


    //sum
    always @(posedge CLK) begin
        if(state == IDLE) sum <= 10'd0;
        else if(state == SORT) sum <= 10'd0;
        else if(state == ADDER && add_counter < 4'd8) sum = sum + Cost;
        else;
    end

    //MatchCount
    always @(posedge CLK) begin
        if(state == IDLE) MatchCount <= 4'd1;
        else if(state == ADDER && add_counter == 4'd8) begin
            if(sum < MinCost) MatchCount <= 4'd1;
            else if(sum == MinCost) MatchCount <= MatchCount + 1'd1;
        end
        else ;
    end

    //MinCost
    always @(posedge CLK) begin
        if(state == IDLE) MinCost <= 10'd1023;
        else if(state == ADDER && add_counter == 4'd8) begin
            if(MinCost > sum) MinCost <= sum;
            else;
        end
    end


    //state change
    always @(posedge CLK) begin
        if(RST) state <= IDLE;
        else state <= next_state;
    end


    //IDLE = 4'd1 , DELAY = 4'd2 , ADDER = 4'd3 , CHANGE_POINT = 4'd4 , FIND_BIG = 4'd5 , SORT = 4'd6 , DONE = 4'd10;
    //next_state change
    always @(*) begin
        case (state)
            IDLE : next_state = DELAY;
            DELAY : next_state = ADDER;
            ADDER : next_state = (add_counter == 4'd8) ? CHANGE_POINT : ADDER ;
            CHANGE_POINT : next_state = (change_point == 3'd7) ?  DONE : FIND_BIG ;
            FIND_BIG : next_state =  bigger_found ? SORT : FIND_BIG;
            SORT : next_state = (sort_counter == 2'd1) ? ADDER : SORT;
            default: ;
        endcase
    end

    //DONE
    /*always @(posedge clk) begin
        if(state == DONE) 
    end*/
    

    assign Valid = (state == DONE);// 可能改next_state 
 
endmodule




/*
vlog tb.sv JAM.v +define+P2
vsim -gui work.testfixture
add wave -r *
run -all
*/