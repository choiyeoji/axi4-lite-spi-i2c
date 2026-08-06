#include "I2C.h"

void I2C_Init(I2C_Typedef_t *I2Cx, uint8_t clk_div, uint8_t slave_addr)
{
    I2Cx->CR = ((uint32_t)slave_addr << I2C_ADDR_SHIFT);
    I2Cx->CLK_DIV = clk_div;
}

void I2C_Write(I2C_Typedef_t *I2Cx, uint16_t tx_data)
{
    I2Cx->TX_DATA = tx_data;

    // CR: slave_addr 유지, rw=0(write), start=1
    uint32_t cr_val = I2Cx->CR & ~((1 << I2C_RW_BIT) | (1 << I2C_START_BIT));
    I2Cx->CR = cr_val | (1 << I2C_START_BIT);
    I2Cx->CR = cr_val;  // start 내림

    // busy 해제 대기
    volatile uint32_t timeout = 100000;
    while ((I2Cx->SR & (1 << I2C_BUSY_BIT)) && timeout > 0) {
        timeout--;
    }
}

uint16_t I2C_Read(I2C_Typedef_t *I2Cx)
{
    // CR: slave_addr 유지, rw=1(read), start=1
    uint32_t cr_val = I2Cx->CR & ~(1 << I2C_START_BIT);
    cr_val |= (1 << I2C_RW_BIT);
    I2Cx->CR = cr_val | (1 << I2C_START_BIT);
    I2Cx->CR = cr_val;  // start 내림

    // busy 해제 대기
    volatile uint32_t timeout = 100000;
    while ((I2Cx->SR & (1 << I2C_BUSY_BIT)) && timeout > 0) {
        timeout--;
    }

    return (uint16_t)(I2Cx->SR & I2C_RX_MASK);
}
