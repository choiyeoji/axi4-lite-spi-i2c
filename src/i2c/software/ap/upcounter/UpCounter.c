#include "UpCounter.h"

hBtn_t hBtnRunStop, hBtnClear;
uint16_t counter = 0;
uint16_t slave_val = 0;

void UpCounter_Init(){
    I2C_Init(I2C0, 49, 0x12);  // clk_div=49, slave_addr=0x12
    FND_Init();
    GPIO_SetMode(GPIOC, GPIO_PIN_0, INPUT);  // SW15 = R/W 모드

    // 마스터의 물리 버튼 초기화 (핀 번호는 하드웨어 환경에 맞게 유지)
    Button_Init(&hBtnRunStop, GPIOA, GPIO_PIN_4);
    Button_Init(&hBtnClear, GPIOA, GPIO_PIN_7);

    counter = 0;
    slave_val = 0;
}

void UpCounter_Excute(){
    uint8_t rw_mode = GPIO_ReadPin(GPIOC, GPIO_PIN_0); // 0=write, 1=read

    static upcounter_state_t upCounterState = STOP;
    static uint8_t prev_rw_mode = 0xFF; // 초기값
    static uint8_t send_clear_flag = 0;

    // R/W 모드가 바뀌면 일단 무조건 정지!
    if (rw_mode != prev_rw_mode) {
        upCounterState = STOP;
        prev_rw_mode = rw_mode;
    }

    // ==========================================
    // 1. I2C 통신 로직 (50ms 주기) - 패킷 전송 포함
    // ==========================================
    static uint32_t prevI2cTime = 0;
    if(millis() - prevI2cTime >= 50) {
        prevI2cTime = millis();

        uint16_t command = (counter & 0x1FFF);
        if (rw_mode) command |= (1 << 15); // Read 모드일 때 1

        if (send_clear_flag) {
            command |= (1 << 14); // Clear 명령 전송
            send_clear_flag = 0;
        } else if (upCounterState == RUN) {
            command |= (1 << 13); // Run 명령 전송
        }

        I2C_Write(I2C0, command);

        if(rw_mode == 1) {
                    slave_val = I2C_Read(I2C0);
         }
    }
    // ==========================================
    // 2. 마스터 버튼 상태 머신 (기존 구조 복원)
    // ==========================================
    switch(upCounterState){
    case STOP:
        UpCounter_Stop();
        if(Button_GetState(&hBtnRunStop) == ACT_PUSHED)
            upCounterState = RUN;
        else if(Button_GetState(&hBtnClear) == ACT_PUSHED)
            upCounterState = CLEAR;
        break;

    case RUN:
        UpCounter_Run();
        if(Button_GetState(&hBtnRunStop) == ACT_PUSHED)
            upCounterState = STOP;
        break;

    case CLEAR:
        UpCounter_Clear();
        send_clear_flag = 1;
        upCounterState = STOP;
        break;

    default:
        UpCounter_Stop();
        break;
    }
}

void UpCounter_DisLoop(){
    FND_DispDigit();
}

// ==========================================
// 3. 상태별 동작 함수 (10ms 주기 적용)
// ==========================================
void UpCounter_Run(){
    static uint32_t prevTimeCounter = 0;
    if(millis() - prevTimeCounter < 10) // 10ms 주기 업데이트!
        return;
    prevTimeCounter = millis();

    uint8_t rw_mode = GPIO_ReadPin(GPIOC, GPIO_PIN_0);
    if(rw_mode == 0) {
        // WRITE 모드: 자체 카운터 올리고 FND에 표시
        if(counter < 9999) counter++;
        FND_SetNum(counter);
    } else {
        // READ 모드: 자체 카운터는 정지, FND에는 슬레이브 값 표시
        FND_SetNum(slave_val);
    }
}

void UpCounter_Stop(){
    uint8_t rw_mode = GPIO_ReadPin(GPIOC, GPIO_PIN_0);
    if(rw_mode == 0)
        FND_SetNum(counter);
    else
        FND_SetNum(slave_val);
}

void UpCounter_Clear(){
    counter = 0;
    // slave_val = 0; // 이제 슬레이브가 알아서 0이 되므로 굳이 안 해도 됨
    FND_SetNum(0);
}
