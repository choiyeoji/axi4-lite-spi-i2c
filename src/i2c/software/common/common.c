#include "common.h"
#include "sleep.h"

volatile uint32_t millis_tick = 0;

uint32_t millis() {
    return millis_tick;
}

void millis_inc() {
    millis_tick++;
}

void delay_ms(uint32_t msec) {
    uint32_t start = millis();
    while (millis() - start < msec);
}

void delay_us(uint32_t usec) {
    usleep(usec);  // Xilinx BSP 함수 사용
}
