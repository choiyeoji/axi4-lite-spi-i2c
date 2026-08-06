`timescale 1ns / 1ps

module spi_master (
    // 시스템 기본 입력
    input logic clk,
    input logic reset,
    input logic cpol,  // idle 0: low, 1: high
    input logic cpha,  // first sampling, 0: first edge, 1: second edge
    // 사용자 제어 입력
    input logic [7:0] clk_div,
    input logic [7:0] tx_data,  // master -> slave
    input logic start,
    // 상태 및 수신 출력
    output logic [7:0] rx_data,  // slave -> master
    output logic done,
    output logic busy,
    // SPI 물리적 4가닥 선
    output logic sclk,  // master가 만듦
    output logic mosi,  // master -> slave
    input logic miso,  // slave -> master
    output logic cs_n  // slave를 깨우는 선 (0일 때 on)
);

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START,
        DATA,
        STOP
    } spi_state_e;

    spi_state_e state;

    logic [7:0] div_cnt;
    logic half_tick;    // sclk의 반 주기마다 1이 되어 박자를 알려주는 신호
    logic [7:0] tx_shift_reg;   // 보낼 데이터를 임시로 담아두고 1bit씩 밀어내는 register
    logic [7:0] rx_shift_reg;   // 받는 데이터를 임시로 담아두고 1bit씩 채우는 register
    logic [2:0] bit_cnt;
    logic step;  // sclk의 수신과 송신을 구분하는 스위치
    logic sclk_r;

    assign sclk = sclk_r;

    // ====================================================================
    // 1. 클럭 분주기 (Clock Divider) 블록
    // Basys3의 100MHz 같은 엄청 빠른 클럭을 우리가 원하는 느린 SPI 클럭으로 쪼개는 역할
    // ====================================================================
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            div_cnt   <= 0;
            half_tick <= 1'b0;
        end else begin
            if (state == DATA) begin    // 데이터를 주고받는 중에만 박자를 만듦
                if (div_cnt == clk_div) begin
                    // 카운터가 목표치(clk_div)에 도달하면 박자(half_tick)를 한 번 치고 다시 0부터 샘
                    div_cnt   <= 0;
                    half_tick <= 1'b1;
                end else begin
                    // 목표치에 도달할 때까지 계속 숫자 증
                    div_cnt   <= div_cnt + 1;
                    half_tick <= 1'b0;
                end
            end
        end
    end

    // ====================================================================
    // 2. 메인 통신 제어 블록 (State Machine)
    // 데이터가 어떻게 나가고 들어오는지를 결정하는 핵심 두뇌
    // ====================================================================
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= IDLE;
            mosi <= 1'b1;
            cs_n <= 1'b1;  // 1이면 슬레이브 안 깨움 (비활성화)
            busy <= 1'b0;
            done <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt <= 0;
            step <= 1'b0;
            rx_data <= 0;
            sclk_r <= cpol;
        end else begin
            done <= 1'b0;
            case (state)
                // 1. 대기 상태 
                IDLE: begin
                    mosi   <= 1'b1;
                    cs_n   <= 1'b1;  // 슬레이브 선택 안 함
                    sclk_r <= cpol;
                    if (start) begin
                        tx_shift_reg <= tx_data;    // 보낼 스위치 데이터를 창고에 복사해 
                        bit_cnt <= 0;
                        step <= 1'b0;
                        busy <= 1'b1;
                        cs_n <= 1'b0;  // 슬레이브를 깨움
                        state <= START;
                    end
                end

                // 2. 시작 상태
                START: begin
                    if (!cpha) begin
                        // 첫 번째 데이터를 mosi에 올려둠 (가장 왼쪽 비트인 7번 비트부터 보냄)
                        mosi         <= tx_shift_reg[7];
                        // 창고에 있는 데이터를 왼쪽으로 한 칸 밀고, 맨 오른쪽 빈자리는 0으로 채움
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                    end
                    state <= DATA;
                end

                // 3. 데이터 전송 상태
                DATA: begin
                    if (half_tick) begin    // 반 주기 박자가 울릴 때마다 동작
                        sclk_r <= ~sclk_r;  // SPI 클럭을 0->1, 1->0으로 토글 시킴
                        // [수신 구간] 슬레이브가 보낸 값을 읽어옴
                        if (step == 0) begin
                            step <= 1'b1;
                            if (!cpha) begin
                                rx_shift_reg <= {rx_shift_reg[6:0], miso};
                            end else begin
                                mosi <= tx_shift_reg[7];
                                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                            end
                            // [송신 구간] 다음번 데이터를 mosi에 올려둠
                        end else begin
                            step <= 1'b0;
                            if (!cpha) begin
                                if (bit_cnt < 7) begin
                                    mosi         <= tx_shift_reg[7];
                                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                end
                            end else begin
                                rx_shift_reg <= {rx_shift_reg[6:0], miso};
                            end
                            if (bit_cnt == 7) begin
                                state <= STOP;
                                if (!cpha) begin
                                    rx_data <= rx_shift_reg;    // 8번 다 받아서 완성된 데이터를 최종 출력으로 내보냄
                                end else begin
                                    //rx_data <= rx_shift_reg;
                                    rx_data <= {rx_shift_reg[6:0], miso};
                                end
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end

                // 4. 통신 종료 상태 
                STOP: begin
                    sclk_r <= 1'b0;
                    cs_n   <= 1'b1;
                    done   <= 1'b1;
                    busy   <= 1'b0;
                    mosi   <= 1'b1;
                    state  <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
