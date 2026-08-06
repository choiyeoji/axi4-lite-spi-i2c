#ifndef SRC_AP_UPCOUNTER_UPCOUNTER_H_
#define SRC_AP_UPCOUNTER_UPCOUNTER_H_
#include "../../driver/FNd/FND.h"
#include "../../driver/Button/Button.h"
#include "../../common/common.h"
#include "../../HAL/I2C/I2C.h"
#include "../../HAL/GPIO/GPIO.h"

typedef enum{
    STOP,
    RUN,
    CLEAR
}upcounter_state_t;

void UpCounter_Init();
void UpCounter_Excute();
void UpCounter_DisLoop();
void UpCounter_Run();
void UpCounter_Stop();
void UpCounter_Clear();
#endif
