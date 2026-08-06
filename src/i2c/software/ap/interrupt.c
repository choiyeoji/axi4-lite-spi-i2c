#include "interrupt.h"

XIntc IntrController;

void TMR0_ISR(void *CallbackRef) {
    millis_inc();
    UpCounter_DisLoop();
}

int SetupInterruptSystem()
{
    int status;
    status = XIntc_Initialize(&IntrController, INTC_DEV_ID);
    if (status != XST_SUCCESS) return XST_FAILURE;

    XIntc_Connect(&IntrController, XPAR_INTC_0_TMR_0_VEC_ID,
                  (XInterruptHandler)TMR0_ISR, (void *)0);

    status = XIntc_Start(&IntrController, XIN_REAL_MODE);
    if (status != XST_SUCCESS) return XST_FAILURE;

    XIntc_Enable(&IntrController, XPAR_INTC_0_TMR_0_VEC_ID);

    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
            (Xil_ExceptionHandler)XIntc_InterruptHandler,
            &IntrController);
    Xil_ExceptionEnable();
    return XST_SUCCESS;
}
