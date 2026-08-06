/*
 * Switch.c
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */

#include "Switch.h"
#include "../../HAL/GPIO/GPIO.h" // GPIOSW와 관련 함수 사용을 위해 포함

void Switch_Init(void) {
    // 스위치 핀들을(일단 16개 핀 모두 0xFFFF) INPUT 모드로 설정
    GPIO_SetMode(GPIOSW, 0xFFFF, INPUT);
}

uint32_t Switch_ReadAll(void) {
    // 스위치 포트 전체의 상태를 한 번에 읽어서 반환
    return GPIO_ReadPort(GPIOSW);
}

uint8_t Switch_ReadState(uint8_t pin) {
    // 특정 핀 번호를 시프트 연산하여 해당 핀의 상태(1 또는 0)만 반환
    return GPIO_ReadPin(GPIOSW, (1 << pin));
}
