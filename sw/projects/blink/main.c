#include "ranger.h"


int main() {

    for (uint32_t i=0; i<16; i++) {
        gpio_mode(GPIOA, i, OUTPUT);
        gpio_mode(GPIOB, i, INPUT);
    }

    while (1) {
        for (uint32_t i=0; i<16; i++) {
            gpio_write(GPIOA, i, gpio_read(GPIOB, i));
        }
    }

    return 0;
}