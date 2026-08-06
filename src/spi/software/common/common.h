/*
 * common.h
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */

#ifndef SRC_COMMON_COMMON_H_
#define SRC_COMMON_COMMON_H_

#include <stdint.h>
#include "sleep.h"
#include "../HAL/SPI/SPI.h"

uint32_t millis();
void millis_inc();
void delay_ms(uint32_t msec);
void delay_us(uint32_t usec);

#endif /* SRC_COMMON_COMMON_H_ */
