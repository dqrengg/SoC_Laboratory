/*
 * SPDX-FileCopyrightText: 2020 Efabless Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * SPDX-License-Identifier: Apache-2.0
 */

// This include is relative to $CARAVEL_PATH (see Makefile)
#include <defs.h>
#ifdef USER_PROJ_IRQ0_EN
#include <irq_vex.h>
#endif
#include "fir.h"
#include "qsort.h"

extern int dma_done_flag;

void __attribute__ ( ( section ( ".mprjram" ) ) ) main() {

#ifdef USER_PROJ_IRQ0_EN
    int mask;
#endif

    reg_mprj_io_31 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_30 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_29 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_28 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_27 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_26 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_25 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_24 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_23 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_22 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_21 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_20 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_19 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_18 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_17 = GPIO_MODE_MGMT_STD_OUTPUT;
    reg_mprj_io_16 = GPIO_MODE_MGMT_STD_OUTPUT;
    
    reg_mprj_xfer = 1;
    while (reg_mprj_xfer == 1);

#ifdef USER_PROJ_IRQ0_EN
    // unmask USER_IRQ_0_INTERRUPT
    mask = irq_getmask();
    mask |= 1 << USER_IRQ_0_INTERRUPT; // USER_IRQ_0_INTERRUPT = 2
    irq_setmask(mask);
    // enable user_irq_0_ev_enable
    user_irq_0_ev_enable_write(1);
#endif
    
    reg_mprj_datal = 0x00A50000;

    fir();
    qsort();

    while (!dma_done_flag);

    reg_mprj_datal = 0x005A0000;

    // for (int i = 0; i < N; i++) {
    //     reg_mprj_datal = Y[i] << 16;
    // }
    // for (int i = 0; i < SIZE; i++) {
    //     reg_mprj_datal = A[i] << 16;
    // }
}
