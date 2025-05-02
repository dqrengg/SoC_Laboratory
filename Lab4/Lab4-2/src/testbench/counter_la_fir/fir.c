#include "fir.h"
#include "defs.h"
#include <stdint.h>

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {

    reg_fir_dlength = N;

    for (uint32_t i = 0; i < 11; i++) {
        reg_fir_coeff(i) = taps[i];
    }

}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(){
    
    initfir();

    reg_mprj_datal = 0x00A50000;

    reg_fir_control = 0x00000001;

    // uint32_t i = 0;

    // while (i < N) {
    //     reg_fir_x = i;
    //     i++;
    //     outputsignal[i-1] = reg_fir_y;
    // }

    // uint32_t i = 1;

    // reg_fir_x = 0;
    // while (i < N) {
    //     outputsignal[i-1] = reg_fir_y;
    //     reg_fir_x = i;
    //     i++;
    // }
    // outputsignal[N-1] = reg_fir_y;

    uint32_t i = 2;

    reg_fir_x = 0;
    reg_fir_x = 1;
    while (i < N) {
        outputsignal[i-2] = reg_fir_y;
        reg_fir_x = i;
        i++;
    }
    outputsignal[N-2] = reg_fir_y;
    outputsignal[N-1] = reg_fir_y;

    uint32_t status = reg_fir_control;

    reg_mprj_datal = 0x005A0000 | (outputsignal[N-1] << 24);

    return outputsignal;
}
        
