/*
 * common.c
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */

#include "common.h"
#include "sleep.h" // Vitis 기본 sleep 함수 사용을 위해 추가

uint32_t millis_tick=0;

uint32_t millis() {
	return millis_tick;
}

void millis_inc() {
	millis_tick++;
}

void delay_ms(uint32_t msec) {
    usleep(msec * 1000); // TMR 대신 usleep 사용!
}

void delay_us(uint32_t usec) {
    usleep(usec);        // TMR 대신 usleep 사용!
}
