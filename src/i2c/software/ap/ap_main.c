#include "ap_main.h"
#include "xil_printf.h"
#include "../driver/FND/FND.h"
#include "../common/common.h"
#include "../HAL/I2C/I2C.h"
#include "UpCounter/UpCounter.h"
#include "../HAL/TMR/TMR.h"
#include "interrupt.h"

void ap_init() {
    UpCounter_Init();
    FND_Init();
    FND_SetNum(0);
    SetupInterruptSystem();

    // TMR0: 1ms 주기 인터럽트 (FND 스캔 + millis)
    TMR_SetPSC(TMR0, 100 - 1);    // 100MHz / 100 = 1us tick
    TMR_SetARR(TMR0, 1000 - 1);   // 1000us = 1ms
    TMR_StartIntr(TMR0);
    TMR_StartTimer(TMR0);
}

void ap_excute() {
    while (1) {
        UpCounter_Excute();
    }
}
