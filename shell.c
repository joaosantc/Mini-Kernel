#include "user.h"

void main(void) {
  printf("Hello World from user application (shell)!\n");
  while (1) {
    for (int i = 0; i < 30000000; i++)
      __asm__ __volatile__("nop");
    printf("[shell] application is running...\n");
  }
}
