/*
 * SPI.h
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */

#ifndef SRC_HAL_SPI_SPI_H_
#define SRC_HAL_SPI_SPI_H_

#include <stdint.h>
#include "xparameters.h"

// Custom SPI IP의 레지스터 구조체 (순서대로 4바이트씩 오프셋 가짐)
typedef struct {
    uint32_t slv_reg0; // 오프셋 0x00 (통신 설정: CPOL, CPHA, clk_div)
    uint32_t slv_reg1; // 오프셋 0x04 (전송 제어: tx_data, start 비트)
    uint32_t slv_reg2; // 오프셋 0x08 (수신 상태: rx_data, done, busy)
    uint32_t slv_reg3; // 오프셋 0x0C (여분)
} SPI_Typedef_t;

// xparameters.h에 있는 SPI 주소를 가져와서 구조체랑 연결!
#define SPI_BASE_ADDR XPAR_SPI_0_S00_AXI_BASEADDR
#define SPI_PORT      ((SPI_Typedef_t *) (SPI_BASE_ADDR))

// 함수 원형 수정 (단방향 Tx -> 양방향 Transfer)
uint8_t SPI_Transfer(SPI_Typedef_t *SPIx, uint8_t tx_data);

#endif /* SRC_HAL_SPI_SPI_H_ */
