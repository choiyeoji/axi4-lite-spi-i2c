#ifndef SRC_COMMON_INTERRUPT_H_
#define SRC_COMMON_INTERRUPT_H_
#include "xparameters.h"
#include "xintc.h"
#include "xil_exception.h"
#include "../common/common.h"
#include "upcounter/UpCounter.h"

#define INTC_DEV_ID     XPAR_INTC_0_DEVICE_ID

void TMR0_ISR(void *CallbackRef);
int SetupInterruptSystem();
#endif
