#ifndef __FIR_H__
#define __FIR_H__

#define DMA_FIR_BASE 0x30000000

#define reg_dma_fir_start   (*(volatile uint32_t*)(DMA_FIR_BASE + 0x00))
#define reg_sdr_tap_base    (*(volatile uint32_t*)(DMA_FIR_BASE + 0x04))
#define reg_sdr_x_base      (*(volatile uint32_t*)(DMA_FIR_BASE + 0x08))
#define reg_sdr_y_base      (*(volatile uint32_t*)(DMA_FIR_BASE + 0x0c))
#define reg_fir_tap_num     (*(volatile uint32_t*)(DMA_FIR_BASE + 0x10))
#define reg_fir_dlength     (*(volatile uint32_t*)(DMA_FIR_BASE + 0x14))

#define N 256

extern int taps[16];
extern int X[N];
extern int Y[N];

void fir();

#endif