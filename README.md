# mini-kernel: Bare-Metal RISC-V 32-bit Operating System

Núcleo monolítico bare-metal implementado em C11 e Assembly para a arquitetura **RISC-V de 32 bits** (`RV32I` / `rv32imafdch`), projetado para execução emulada sobre a plataforma virtual `virt` do **QEMU** em cooperação com firmware **OpenSBI**.

O sistema implementa do zero os mecanismos fundamentais de isolamento de privilégio, paginação virtual em dois níveis (Sv32), escalonamento preemptivo de processos, vetores de trap com tratamento de exceções e chamadas de sistema (*system calls*), além de uma aplicação de usuário (*shell*) embutida.

---

## 1. Arquitetura e Subsistemas do Kernel

```text
mini-kernel/
├── kernel/
│   ├── kernel.c          # Ponto de entrada, paginação Sv32, escalonador e trap handler
│   ├── kernel.h          # Definições de CSRs, PCB (struct process) e flags de página
│   └── kernel.ld         # Linker script: mapeia seções (.text, .rodata, .data, .bss, RAM)
├── user/
│   ├── shell.c           # Aplicação em user-space executando em U-mode
│   ├── user.c            # Runtime de usuário: vetor de inicialização, syscalls (ecall) e exit
│   ├── user.h            # Protótipos de chamadas e interface de biblioteca de usuário
│   └── user.ld           # Linker script do processo de usuário (origem em 0x01000000)
├── common/
│   ├── common.c          # Implementação freestanding de funções de suporte (memcpy, printf)
│   └── common.h          # Tipos primitivos estritos (uint32_t, paddr_t, vaddr_t) e macros
└── Makefile              # Pipeline de build determinístico via Clang, LLD e llvm-objcopy
```

### A. Bootstrap e Níveis de Privilégio (M $\rightarrow$ S $\rightarrow$ U)
1. **Machine-mode (M-Mode):** O emulador QEMU inicializa o firmware OpenSBI em `0x80000000`, preparando os registradores de deleção de traps (`mideleg`, `medeleg`) e saltando para o endereço de carga do kernel (`0x80200000`) em *Supervisor-mode*.
2. **Supervisor-mode (S-Mode):** A rotina `boot` em [`kernel/kernel.c`](kernel/kernel.c) inicializa o ponteiro de pilha (`sp = __stack_top`), zera a seção `.bss`, configura o vetor de exceções (`stvec = kernel_entry`) e instancia as tabelas de páginas do processo sentinela (`idle_proc`) e da aplicação de usuário.
3. **User-mode (U-Mode):** A transição de privilégio é orquestrada pela rotina `user_entry`. Através da instrução `sret`, o registrador `sepc` é carregado com `USER_BASE (0x01000000)` e o registrador `sstatus` tem o bit `SPIE` (*Previous Interrupt Enable*) ativado, rebaixando a CPU para execução não privilegiada.

---

### B. Gerenciamento de Memória Virtual (Paginação Sv32)
O kernel opera sob o esquema padrão **RISC-V Sv32**, traduzindo endereços virtuais de 32 bits em endereços físicos de 34 bits através de uma hierarquia de tabelas de dois níveis com páginas de $4\text{ KB}$ ($2^{12}\text{ bytes}$):

$$\text{Endereço Virtual} = \underbrace{\text{VPN}[1]}_{10\text{ bits}} \;\Vert\; \underbrace{\text{VPN}[0]}_{10\text{ bits}} \;\Vert\; \underbrace{\text{Offset}}_{12\text{ bits}}$$

* **Alocador Físico de Quadros (`alloc_pages`):** Alocador sequencial com alinhamento estrito a fronteiras de página ($4\text{ KB}$), gerenciando a região física delimitada entre `__free_ram` e `__free_ram_end`.
* **Mapeamento de Identidade do Kernel:** Mapeia a memória do kernel com permissões de leitura, escrita e execução (`PAGE_R | PAGE_W | PAGE_X | PAGE_V`).
* **Espaço de Endereçamento do Usuário:** Cria tabelas de segundo nível sob demanda (`map_page`), mapeando a imagem do executável em `USER_BASE (0x01000000)` com o bit de privilégio de usuário ativo (`PAGE_U`). A ausência de `PAGE_U` em páginas do kernel garante que qualquer tentativa de acesso a dados privilegiados a partir de U-mode resulte em *Page Fault* imediato.

---

### C. Estrutura de Memória Física e Virtual

```text
             MEMÓRIA FÍSICA (RAM)                         MEMÓRIA VIRTUAL (PROCESSO)
   0x80000000 ┌───────────────────────────┐       0x00000000 ┌───────────────────────────┐
              │ Firmware OpenSBI (M-mode) │                  │ Área Não Mapeada (Guard)  │
   0x80200000 ├───────────────────────────┤       0x01000000 ├───────────────────────────┤ USER_BASE
              │ Kernel (.text, .rodata)   │                  │ Código/Dados da Aplicação │
              ├───────────────────────────┤                  ├───────────────────────────┤
              │ Dados e BSS (.data, .bss) │                  │ Pilha do Usuário          │
              ├───────────────────────────┤       0x80200000 ├───────────────────────────┤
              │ Pilha de Boot do Kernel   │                  │ Mapeamento de Identidade  │
   __free_ram ├───────────────────────────┤                  │ do Kernel (Supervisor)    │
              │ Quadros de Páginas        │                  │ [PAGE_U = 0: Protegido]   │
              │ Gerenciados Dinamicamente │       0xFFFFFFFF └───────────────────────────┘
   0x88000000 └───────────────────────────┘
```

---

### D. Processos, Escalonamento e Troca de Contexto
* **Process Control Block (`struct process`):** Mantém o identificador do processo (`pid`), estado (`PROC_UNUSED`, `PROC_RUNNABLE`), pilha de execução dedicada de $8\text{ KB}$ (`stack[8192]`) e endereço físico da tabela de páginas raiz (`page_table`).
* **Troca de Contexto (`switch_context`):** Operação atômica em Assembly que salva os registradores *callee-saved* da ABI RISC-V (`ra`, `s0-s11`) na pilha do processo atual e restaura o contexto do próximo processo a ser executado.
* **Escalonamento Round-Robin (`yield`):** Itera pela tabela de processos ativos alternando a execução cooperativamente. Ao trocar de contexto, o registrador de controle `satp` (*Supervisor Address Translation and Protection*) é atualizado com a raiz da nova tabela de páginas e a instrução `sfence.vma` invalida as entradas correspondentes no TLB (*Translation Lookaside Buffer*).

---

### E. Tratamento de Traps, Exceções e Chamadas de Sistema
* **Entrada de Trap (`kernel_entry`):** Ao ocorrer uma exceção ou interrupção, o hardware transfere o controle para o endereço configurado no CSR `stvec`. A rotina `kernel_entry` executa a troca atômica do ponteiro de pilha (`csrrw sp, sscratch, sp`), aloca espaço para a `struct trap_frame` e empilha os 31 registradores gerais da CPU.
* **Despacho de System Calls:** Exceções do tipo *Environment Call from U-mode* (`scause = 8`) são interceptadas pelo tratador `handle_trap`. O argumento transmitido no registrador `a0` é consumido (e.g., impressão de caractere via console SBI), e o endereço de retorno em `sepc` é incrementado em $+4$ bytes antes de retornar ao usuário via `sret`.
* **Kernel Panic com Diagnóstico Completo:** Traps inesperadas (falhas de página, instruções ilegais, violações de alinhamento) despejam os valores dos CSRs `scause`, `stval` e `sepc` na saída padrão antes de congelar a CPU em laço seguro.

---

### F. Runtime de Usuário e Embutimento de Binários
O processo de build desacopla completamente o espaço de usuário do kernel:
1. O código de usuário ([`user/shell.c`](user/shell.c) e [`user/user.c`](user/user.c)) é compilado e linkado pelo Clang/LLD usando o script [`user/user.ld`](user/user.ld), gerando o executável ELF `shell.elf`.
2. A ferramenta `llvm-objcopy` extrai a imagem binária crua (`shell.bin`).
3. Uma segunda passagem com `llvm-objcopy -Ibinary -Oelf32-littleriscv` encapsula o binário em um arquivo objeto relocável (`shell.bin.o`), expondo os símbolos `_binary_shell_bin_start` e `_binary_shell_bin_size`.
4. O kernel linka diretamente esse objeto, permitindo carregar e inicializar processos de usuário a partir da memória física sem a necessidade de um sistema de arquivos externo.

---

## 2. Instruções de Compilação e Emulação

### Pré-requisitos
* **Clang / LLVM** com suporte a RISC-V (alvo `riscv32-unknown-elf` e linker `lld`).
* **llvm-objcopy**
* **qemu-system-riscv32**

Em distribuições baseadas em Debian/Ubuntu:
```bash
sudo apt-get update
sudo apt-get install clang lld llvm qemu-system-misc
```

### Compilação
```bash
make
```
Compila a aplicação de usuário, gera os binários intermediários, embuti o executável no objeto e gera a imagem consolidada em `build/kernel.elf`.

### Execução no QEMU
```bash
make run
```
Inicializa a máquina virtual RISC-V (`-machine virt`), carrega o firmware OpenSBI padrão e executa o kernel com redirecionamento de I/O para a saída do terminal (`-nographic`).

Para encerrar a emulação do QEMU a qualquer momento: pressione `Ctrl + A` seguido de `X`.

### Limpeza de Artefatos
```bash
make clean
```

---

## 3. Autoria

* **João Pedro Sant'Ana de Carvalho** ([@santcjoao](https://github.com/santcjoao)) — Concepção, implementação dos subsistemas de bootstrap, paginação Sv32, escalonamento e arquitetura de build bare-metal.
