/*
 * Switch.h
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */

#ifndef SRC_DRIVER_SWITCH_SWITCH_H_
#define SRC_DRIVER_SWITCH_SWITCH_H_

#include <stdint.h>

// 스위치 초기화
void Switch_Init(void);

// 전체 스위치 상태를 한 번에 읽기 (예: 16개 스위치 값을 정수로 반환)
uint32_t Switch_ReadAll(void);

// 특정 스위치 1개의 상태만 읽기 (0 또는 1 반환)
uint8_t Switch_ReadState(uint8_t pin);

#endif /* SRC_DRIVER_SWITCH_SWITCH_H_ */
