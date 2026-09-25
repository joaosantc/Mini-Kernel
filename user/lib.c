#include "user.h"

extern char __stack_top[];

void putchar(char ch) {
  register long a0 __asm__("a0") = ch;
  __asm__ __volatile__("ecall" : "+r"(a0) :: "memory");
}

__attribute__((noreturn)) void exit(void) {
  for (;;)
    ;
}

__attribute__((section(".text.start"))) __attribute__((naked)) void start(void) {
  __asm__ __volatile__("mv sp, %[stack_top] \n"
                       "call main           \n"
                       "call exit           \n"
                       ::[stack_top] "r"(__stack_top));
}
