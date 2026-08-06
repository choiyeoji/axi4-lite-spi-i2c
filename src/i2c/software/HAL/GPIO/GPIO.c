/*
 * GPIO.c
 *
 *  Created on: 2026. 4. 28.
 *      Author: kccistc
 */
#include "GPIO.h"

void GPIO_SetMode(GPIO_Typedef_t *GPIOx, uint32_t GPIO_pin, int GPIO_Dir){
	if(GPIO_Dir == OUTPUT){
		GPIOx -> CR |= GPIO_pin;
	}
	else {
		GPIOx -> CR &= ~(GPIO_pin);

	}
}

void GPIO_WritePin(GPIO_Typedef_t *GPIOx, uint32_t GPIO_Pin, int data){
	if(data == SET){
		GPIOx->ODR |= GPIO_Pin;
	} else {
		GPIOx-> ODR &= ~GPIO_Pin;
	}
}

uint32_t GPIO_ReadPin(GPIO_Typedef_t *GPIOx, uint32_t GPIO_Pin){
	return (GPIOx -> IDR & GPIO_Pin) ? 1 :0;   //0은거짓 나머지는 다 참
}

void GPIO_WritePort(GPIO_Typedef_t *GPIOx, int data){
	GPIOx -> ODR = data;
}


uint32_t GPIO_ReadPort(GPIO_Typedef_t *GPIOx){
	return GPIOx  -> IDR;   //0은거짓 나머지는 다 참
}
