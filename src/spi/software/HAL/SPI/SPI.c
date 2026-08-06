/*
 * SPI.c
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */

#include "SPI.h"

// 데이터를 보내는 동시에 받아오는 양방향 함수로 변경
uint8_t SPI_Transfer(SPI_Typedef_t *SPIx, uint8_t tx_data)
{
    // 1. tx_data(7:0)와 start 비트(31)를 동시에 세팅하여 전송 시작
    // (1 << 31)은 0x80000000 입니다.
    SPIx->slv_reg1 = (1 << 31) | tx_data;

    // 2. 하드웨어가 통신을 마칠 때까지(done 비트인 bit 8이 1이 될 때까지) 대기
    while ((SPIx->slv_reg2 & (1 << 8)) == 0);

    // 3. start 비트 초기화 (다음 전송을 위해)
    SPIx->slv_reg1 &= ~(1 << 31);

    // 4. 수신된 데이터(rx_data)가 slv_reg2의 하위 8비트에 있으므로 반환
    return (SPIx->slv_reg2 & 0xFF);
}
