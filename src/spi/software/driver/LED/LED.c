/*
 * LED.c
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */

#include "LED.h"
#include "../../HAL/GPIO/GPIO.h" // GPIOC와 관련 함수 사용을 위해 포함

void LED_Init(void) {
    // LED 핀들을(일단 16개 핀 모두 0xFFFF) OUTPUT 모드로 설정
    GPIO_SetMode(GPIOC, 0xFFFF, OUTPUT);
}

void LED_On(uint8_t pin) {
    // pin 번호를 시프트 연산하여 해당 비트만 SET
    GPIO_WritePin(GPIOC, (1 << pin), SET);
}

void LED_Off(uint8_t pin) {
    // pin 번호를 시프트 연산하여 해당 비트만 RESET
    GPIO_WritePin(GPIOC, (1 << pin), RESET);
}

void LED_Toggle(uint8_t pin) {
    // ODR(출력 데이터 레지스터)의 현재 상태를 읽어서 해당 핀이 켜져있으면 끄고, 꺼져있으면 켬
    if (GPIOC->ODR & (1 << pin)) {
        GPIO_WritePin(GPIOC, (1 << pin), RESET);
    } else {
        GPIO_WritePin(GPIOC, (1 << pin), SET);
    }
}

void LED_Write(uint32_t data) {
    // 포트 전체에 값을 한 번에 씀 (예: 카운터 값 출력)
    GPIO_WritePort(GPIOC, data);
}
