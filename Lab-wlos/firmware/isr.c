// This file is Copyright (c) 2020 Florent Kermarrec <florent@enjoy-digital.fr>
// License: BSD

#include <csr.h>
#include <soc.h>
#include <irq_vex.h>
#include <uart.h>
#include <defs.h>

volatile int dma_done_flag = 0;

#ifdef CONFIG_CPU_HAS_INTERRUPT

void isr(void) {
#ifndef USER_PROJ_IRQ0_EN
    irq_setmask(0);
#else
    uint32_t irqs = irq_pending() & irq_getmask();
    if (irqs & (1 << USER_IRQ_0_INTERRUPT)) {
        dma_done_flag = 1;
    }
#endif
}

#else

void isr(void) {};

#endif
