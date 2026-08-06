#ifndef SRC_HAL_I2C_I2C_H_
#define SRC_HAL_I2C_I2C_H_
#include "xparameters.h"
#include <stdint.h>

typedef struct {
    uint32_t CR;        // 0x00: bit[0]=start, bit[1]=rw, bit[13:7]=slave_addr
    uint32_t CLK_DIV;   // 0x04: bit[7:0]
    uint32_t TX_DATA;   // 0x08: bit[15:0]
    uint32_t SR;        // 0x0C: bit[15:0]=rx_data, bit[16]=done, bit[17]=busy
} I2C_Typedef_t;

#define I2C0_BASEADDR   XPAR_AXI_I2C_0_S00_AXI_BASEADDR
#define I2C0            ((I2C_Typedef_t *)(I2C0_BASEADDR))

#define I2C_START_BIT   0
#define I2C_RW_BIT      1
#define I2C_ADDR_SHIFT  7
#define I2C_DONE_BIT    16
#define I2C_BUSY_BIT    17
#define I2C_RX_MASK     0xFFFF

void I2C_Init(I2C_Typedef_t *I2Cx, uint8_t clk_div, uint8_t slave_addr);
void I2C_Write(I2C_Typedef_t *I2Cx, uint16_t tx_data);
uint16_t I2C_Read(I2C_Typedef_t *I2Cx);

#endif
