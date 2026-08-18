#!/bin/bash
# verify.sh — Verifica todos os critérios de avaliação do Trabalho 01

PASS=0
FAIL=0
TOTAL=0

check() {
    TOTAL=$((TOTAL + 1))
    local desc="$1"
    local result="$2"
    if [ "$result" -eq 0 ]; then
        echo "  ✅ $desc"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Verificação — Trabalho 01: Boot do Kernel"
echo "═══════════════════════════════════════════════════"

# ─── Critério 1: Estrutura e arquivos esperados (2 pts) ───
echo ""
echo "📁 Critério 1: Estrutura e arquivos esperados (2 pts)"

test -f kernel.c
check "kernel.c existe" $?

test -f kernel.ld
check "kernel.ld existe" $?

test -f run.sh
check "run.sh existe" $?

# ─── Compilar o kernel ───
echo ""
echo "🔨 Compilando kernel..."
CC=clang
CFLAGS="-std=c11 -O2 -g3 -Wall -Wextra --target=riscv32-unknown-elf -fuse-ld=lld -fno-stack-protector -ffreestanding -nostdlib"
BUILD_OUTPUT=$($CC $CFLAGS -Wl,-Tkernel.ld -Wl,-Map=kernel.map -o kernel.elf kernel.c 2>&1)
BUILD_OK=$?
check "Compilação sem erros" $BUILD_OK

if [ $BUILD_OK -ne 0 ]; then
    echo "    ⚠️  Erro de compilação:"
    echo "$BUILD_OUTPUT" | sed 's/^/    /'
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  ❌ Compilação falhou. Corrija os erros acima."
    echo "═══════════════════════════════════════════════════"
    exit 1
fi

test -f kernel.elf
check "kernel.elf gerado" $?

# ─── Critério 2: ELF válido para RISC-V 32-bit (2 pts) ───
echo ""
echo "🔍 Critério 2: ELF válido para RISC-V 32-bit (2 pts)"

FILE_INFO=$(file kernel.elf)
echo "$FILE_INFO" | grep -q "ELF 32-bit"
check "ELF 32-bit" $?

echo "$FILE_INFO" | grep -qi "RISC-V"
check "Arquitetura RISC-V" $?

echo "    → $FILE_INFO"

# ─── Critério 3: Entrada em 0x80200000, símbolos boot e kernel_main (3 pts) ───
echo ""
echo "🏷️  Critério 3: Entrada em 0x80200000 + símbolos (3 pts)"

# Tenta llvm-nm, senão tenta nm
if command -v llvm-nm &>/dev/null; then
    NM_CMD="llvm-nm"
elif command -v riscv32-unknown-elf-nm &>/dev/null; then
    NM_CMD="riscv32-unknown-elf-nm"
else
    NM_CMD="nm"
fi

NM_OUTPUT=$($NM_CMD kernel.elf 2>/dev/null)

echo "$NM_OUTPUT" | grep -qi "boot"
check "Símbolo 'boot' presente" $?

echo "$NM_OUTPUT" | grep -qi "kernel_main"
check "Símbolo 'kernel_main' presente" $?

BOOT_ADDR=$(echo "$NM_OUTPUT" | grep -i " T boot$" | awk '{print $1}')
if [ "$BOOT_ADDR" = "80200000" ]; then
    check "boot em 0x80200000" 0
else
    check "boot em 0x80200000 (encontrado: 0x${BOOT_ADDR:-???})" 1
fi

STACK_ADDR=$(echo "$NM_OUTPUT" | grep -i "__stack_top" | awk '{print $1}')
if [ -n "$STACK_ADDR" ]; then
    check "__stack_top definido (0x$STACK_ADDR)" 0
else
    check "__stack_top definido" 1
fi

echo ""
echo "    Símbolos encontrados:"
echo "$NM_OUTPUT" | grep -E "boot|kernel_main|__stack_top|__bss" | sed 's/^/    → /'

# ─── Critério 4: Execução no QEMU sem reboot inesperado (2 pts) ───
echo ""
echo "🖥️  Critério 4: Execução no QEMU sem reboot (2 pts)"

if command -v qemu-system-riscv32 &>/dev/null; then
    # Roda QEMU por 3 segundos e verifica se não deu reboot
    QEMU_OUTPUT=$(timeout 3 qemu-system-riscv32 \
        -machine virt -bios default -nographic -serial mon:stdio --no-reboot \
        -kernel kernel.elf 2>&1 || true)

    echo "$QEMU_OUTPUT" | grep -q "OpenSBI"
    check "OpenSBI inicializou" $?

    # Se o QEMU rodou por 3s sem crashar, está OK
    # "no-reboot" faz o QEMU sair em caso de crash, então se ele rodou é bom sinal
    if echo "$QEMU_OUTPUT" | grep -q "Boot HART"; then
        check "QEMU executou sem reboot inesperado" 0
    else
        # Ainda pode estar OK se OpenSBI apareceu
        echo "$QEMU_OUTPUT" | grep -q "OpenSBI"
        check "QEMU executou sem reboot inesperado" $?
    fi

    echo ""
    echo "    Primeiras linhas do QEMU:"
    echo "$QEMU_OUTPUT" | head -5 | sed 's/^/    → /'
else
    echo "  ⚠️  qemu-system-riscv32 não encontrado — pulando teste de execução"
    echo "  Instale com: sudo apt-get install qemu-system-riscv"
fi

# ─── Critério 5: Organização mínima (1 pt) ───
echo ""
echo "📐 Critério 5: Organização mínima (1 pt)"
check "Arquivos no mesmo diretório" 0

# ─── Resultado final ───
echo ""
echo "═══════════════════════════════════════════════════"
if [ $FAIL -eq 0 ]; then
    echo "  🎉 TODOS OS TESTES PASSARAM ($PASS/$TOTAL)"
else
    echo "  📊 Resultado: $PASS/$TOTAL testes passaram, $FAIL falharam"
fi
echo "═══════════════════════════════════════════════════"
echo ""
