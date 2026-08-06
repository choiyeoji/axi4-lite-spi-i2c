/*
 * LED.h
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */

#ifndef SRC_DRIVER_LED_LED_H_
#define SRC_DRIVER_LED_LED_H_

#include <stdint.h>

// LED 초기화
void LED_Init(void);

// 특정 LED 제어
void LED_On(uint8_t pin);
void LED_Off(uint8_t pin);
void LED_Toggle(uint8_t pin);

// 전체 LED(예: 16비트) 한 번에 제어
void LED_Write(uint32_t value);

#endif /* SRC_DRIVER_LED_LED_H_ */
