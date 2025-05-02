#ifndef __FIR_H__
#define __FIR_H__

#define N 16

#define reg_fir_control  (*(volatile uint32_t*)0x30000000)
#define reg_fir_dlength  (*(volatile uint32_t*)0x30000010)
#define reg_fir_coeff(i) (*(volatile uint32_t*)(0x30000080 + (i << 2)))
#define reg_fir_x        (*(volatile uint32_t*)0x30000040)
#define reg_fir_y        (*(volatile uint32_t*)0x30000044)

int taps[11] = { 0, -10, -9, 23, 56, 63, 56, 23, -9, -10, 0 };
int outputsignal[N];

#endif
