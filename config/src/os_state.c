#include "os_state.h"
static uint8_t current_lang = 0; // 0: Mac, 1: Win, 2: Lin

void set_os(uint8_t lang) { current_lang = lang; }
uint8_t get_os(void) { return current_lang; }