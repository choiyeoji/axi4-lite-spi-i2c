/*
 * ap_main.c
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */

#include "ap_main.h"
#include "xil_printf.h"
#include "../HAL/GPIO/GPIO.h"
#include "../HAL/SPI/SPI.h"
#include "../driver/FND/FND.h"
#include "../driver/LED/LED.h"       // LED 헤더 추가
#include "../driver/Switch/Switch.h" // 스위치 헤더 추가
#include "../common/common.h"

void ap_init()
{
    FND_Init();
    LED_Init();    // LED 초기화
    Switch_Init(); // 스위치 초기화

    // SPI 초기 설정 (slv_reg0)
    // CPOL=0, CPHA=0, clk_div=10 (필요에 따라 분주비 조정)
    SPI_PORT->slv_reg0 = (10 << 8) | (0 << 1) | 0;

    xil_printf("AP Initialization Complete!\n\r");
}

void ap_excute()
{
    uint8_t tx_sw_data = 0;
    uint8_t rx_slv_data = 0;

    xil_printf("=== SPI Bidirectional System Running ===\n\r");

    while (1)
    {
        // 1. 마스터 보드의 스위치 값 읽기 (보낼 데이터)
        tx_sw_data = Switch_ReadAll() & 0xFF;

        // 2. SPI 양방향 통신! (내 스위치 값을 보내고, 슬레이브 스위치 값을 받아옴)
        // 변화가 없어도 지속적으로 호출하여 슬레이브의 데이터를 가져옵니다.
        rx_slv_data = SPI_Transfer(SPI_PORT, tx_sw_data);

        // 3. 수신한 슬레이브의 데이터를 내 보드(마스터)의 LED와 FND에 표시
        LED_Write(rx_slv_data);
        FND_SetNum(rx_slv_data);
        FND_DispDigit(); // 잔상 유지

        // 4. 통신 속도 및 FND 깜빡임 조절용 딜레이
        delay_us(2000);
    }
}
