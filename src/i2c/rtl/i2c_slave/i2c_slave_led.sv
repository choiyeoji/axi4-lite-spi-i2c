`timescale 1ns / 1ps

module i2c_slave_led_fnd (
    input  logic       clk,
    input  logic       reset,
    input  logic       scl,
    inout  wire        sda,
    input  logic [7:0] slave_sw,   // 🚨 [추가됨] 슬레이브 보드의 스위치 입력
    output logic [7:0] led,
    output logic [7:0] fnd_data,   // 이름 변경: FND 세그먼트 (a~g, dp)
    output logic [3:0] fnd_digit   // 이름 변경: FND 자릿수 선택
);

    localparam [6:0] I2C_ADDR = 7'h25; 

    // ==================================================
    // 1. I2C 수신/송신부
    // ==================================================
    logic [2:0] scl_sync, sda_sync;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            scl_sync <= 3'b111;
            sda_sync <= 3'b111;
        end else begin
            scl_sync <= {scl_sync[1:0], scl};
            sda_sync <= {sda_sync[1:0], sda};
        end
    end

    logic scl_high, scl_rising, scl_falling;
    assign scl_high    = scl_sync[1];
    assign scl_rising  = (scl_sync[2:1] == 2'b01);
    assign scl_falling = (scl_sync[2:1] == 2'b10);

    logic sda_high, sda_rising, sda_falling;
    assign sda_high    = sda_sync[1];
    assign sda_rising  = (sda_sync[2:1] == 2'b01);
    assign sda_falling = (sda_sync[2:1] == 2'b10);

    logic start_det, stop_det;
    assign start_det = sda_falling & scl_high;
    assign stop_det  = sda_rising  & scl_high;

    // 🚨 [수정됨] 상태 머신에 SEND_DATA, WAIT_ACK 추가 (총 7개 상태이므로 3비트 유지)
    typedef enum logic [2:0] {
        IDLE, GET_ADDR, ACK_ADDR, GET_DATA, ACK_DATA, SEND_DATA, WAIT_ACK
    } state_e;

    state_e state;
    logic [7:0] shift_reg;
    logic [3:0] bit_cnt;
    logic       sda_out;
    logic       sda_oe;
    
    // 🚨 [추가됨] Read 동작을 위한 변수
    logic [7:0] tx_reg;  
    logic       is_read; 

    assign sda = sda_oe ? sda_out : 1'bz;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state     <= IDLE;
            shift_reg <= 8'd0;
            bit_cnt   <= 4'd0;
            led       <= 8'd0;
            sda_out   <= 1'b1;
            sda_oe    <= 1'b0;
            tx_reg    <= 8'd0;  // 🚨 초기화 추가
            is_read   <= 1'b0;  // 🚨 초기화 추가
        end else begin
            if (start_det) begin
                state   <= GET_ADDR;
                bit_cnt <= 4'd0;
                sda_oe  <= 1'b0;
            end else if (stop_det) begin
                state   <= IDLE;
                sda_oe  <= 1'b0;
            end else begin
                if (scl_rising) begin
                    if (state == GET_ADDR || state == GET_DATA) begin
                        shift_reg <= {shift_reg[6:0], sda_high};
                        bit_cnt   <= bit_cnt + 1;
                    end
                end
                
                if (scl_falling) begin
                    case (state)
                        IDLE: sda_oe <= 1'b0;
                        
                        GET_ADDR: begin
                            if (bit_cnt == 4'd8) begin
                                // 🚨 [수정됨] 읽기(1)든 쓰기(0)든 내 주소면 무조건 받도록 조건 수정
                                if (shift_reg[7:1] == I2C_ADDR) begin
                                    state   <= ACK_ADDR;
                                    sda_oe  <= 1'b1;
                                    sda_out <= 1'b0;
                                    is_read <= shift_reg[0]; // 🚨 맨 끝 비트가 읽기인지 쓰기인지 저장
                                end else begin
                                    state   <= IDLE;
                                end
                                bit_cnt <= 4'd0;
                            end
                        end
                        
                        ACK_ADDR: begin
                            // 🚨 [수정됨] 읽기 모드와 쓰기 모드 분기 처리
                            if (is_read) begin
                                state   <= SEND_DATA; // 마스터에게 데이터를 보내러 감
                                sda_oe  <= 1'b1;      // SDA 선 제어권 획득
                                tx_reg  <= slave_sw;  // 슬레이브 스위치 값을 레지스터에 복사
                                sda_out <= slave_sw[7]; // 첫 번째 비트(최상위) 출력
                                bit_cnt <= 4'd1;
                                led <= slave_sw;
                            end else begin
                                state   <= GET_DATA;  // 기존처럼 데이터 받으러 감
                                sda_oe  <= 1'b0;
                            end
                        end
                        
                        // --- [마스터 -> 슬레이브 (쓰기 모드)] ---
                        GET_DATA: begin
                            if (bit_cnt == 4'd8) begin
                                state   <= ACK_DATA;
                                sda_oe  <= 1'b1;
                                sda_out <= 1'b0;
                                led     <= shift_reg; 
                                bit_cnt <= 4'd0;
                            end
                        end
                        ACK_DATA: begin
                            state  <= GET_DATA;
                            sda_oe <= 1'b0;
                        end

                        // --- 🚨 [슬레이브 -> 마스터 (읽기 모드 새로 추가!)] ---
                        SEND_DATA: begin
                            if (bit_cnt == 4'd8) begin
                                state   <= WAIT_ACK;
                                sda_oe  <= 1'b0; // 8비트 전송 완료. 마스터가 NACK 보낼 수 있게 선을 놓음
                                bit_cnt <= 4'd0;
                            end else begin
                                sda_out <= tx_reg[6];             // 다음 비트 밀어내기
                                tx_reg  <= {tx_reg[6:0], 1'b0};   // 남은 데이터 왼쪽으로 시프트
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                        WAIT_ACK: begin
                            state  <= IDLE; // 마스터의 NACK 수신 후 종료
                            sda_oe <= 1'b0;
                        end
                        
                        default: state <= IDLE;
                    endcase
                end
            end
        end
    end

    // ==================================================
    // 2. FND 다이내믹 구동부 (기존과 100% 동일)
    // ==================================================
    
    logic [17:0] scan_cnt;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) scan_cnt <= 0;
        else       scan_cnt <= scan_cnt + 1;
    end

    logic [1:0] digit_sel;
    assign digit_sel = scan_cnt[17:16];

    logic [3:0] bcd_val;
    always_comb begin
        case(digit_sel)
            2'b00: bcd_val = led % 10;             
            2'b01: bcd_val = (led / 10) % 10;      
            2'b10: bcd_val = (led / 100) % 10;     
            2'b11: bcd_val = 0;                    
        endcase
    end

    always_comb begin
        case(digit_sel)
            2'b00: fnd_digit = 4'b1110; 
            2'b01: fnd_digit = 4'b1101; 
            2'b10: fnd_digit = 4'b1011; 
            2'b11: fnd_digit = 4'b0111; 
        endcase
    end

    always_comb begin
        case(bcd_val)
            4'd0: fnd_data = 8'hC0;
            4'd1: fnd_data = 8'hF9;
            4'd2: fnd_data = 8'hA4;
            4'd3: fnd_data = 8'hB0;
            4'd4: fnd_data = 8'h99;
            4'd5: fnd_data = 8'h92;
            4'd6: fnd_data = 8'h82;
            4'd7: fnd_data = 8'hF8;
            4'd8: fnd_data = 8'h80;
            4'd9: fnd_data = 8'h90;
            default: fnd_data = 8'hFF; 
        endcase
    end

endmodule