/*
 * main.c
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */

#include "ap/ap_main.h"

int main()
{
    // 1. 모든 장치 초기화
    ap_init();

    // 2. 무한 루프 실행
    ap_excute();

    return 0;
}
