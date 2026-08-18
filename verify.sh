#!/bin/bash
# verify.sh — Verifica todos os critérios de avaliação do Trabalho 02

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
echo "  Verificação — Trabalho 02: Hello World com SBI"
echo "═══════════════════════════════════════════════════"

# ─── Critério 1: Estrutura da submissão (2 pts) ───
echo ""
echo "📁 Critério 1: Estrutura da submissão (2 pts)"

test -f kernel.c;  check "kernel.c existe" $?
test -f kernel.ld; check "kernel.ld existe" $?
test -f kernel.h;  check "kernel.h existe" $?
test -f common.c;  check "common.c existe" $?
test -f common.h;  check "common.h existe" $?
test -f run.sh;    check "run.sh existe" $?

# ─── Critério 2: Build ou ELF válido (2 pts) ───
echo ""
echo "🔨 Critério 2: Build ou ELF válido (2 pts)"

CC=clang
CFLAGS="-std=c11 -O2 -g3 -Wall -Wextra --target=riscv32-unknown-elf -fuse-ld=lld -fno-stack-protector -ffreestanding -nostdlib"
BUILD_OUTPUT=$($CC $CFLAGS -Wl,-Tkernel.ld -Wl,-Map=kernel.map -o kernel.elf kernel.c common.c 2>&1)
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

FILE_INFO=$(file kernel.elf)
echo "$FILE_INFO" | grep -q "ELF 32-bit";  check "ELF 32-bit" $?
echo "$FILE_INFO" | grep -qi "RISC-V";     check "Arquitetura RISC-V" $?
echo "    → $FILE_INFO"

# ─── Critério 3: Saída serial contém a mensagem esperada (4 pts) ───
echo ""
echo "📨 Critério 3: Saída serial contém mensagem esperada (4 pts)"

if command -v qemu-system-riscv32 &>/dev/null; then
    QEMU_OUTPUT=$(timeout 3 qemu-system-riscv32 \
        -machine virt -bios default -nographic -serial mon:stdio --no-reboot \
        -kernel kernel.elf 2>&1 || true)

    echo "$QEMU_OUTPUT" | grep -q "Hello"
    check "Saída contém 'Hello'" $?

    echo "$QEMU_OUTPUT" | grep -q "World"
    check "Saída contém 'World'" $?

    echo "$QEMU_OUTPUT" | grep -q "1 + 2 = 3"
    check "printf %d funciona ('1 + 2 = 3')" $?

    echo "$QEMU_OUTPUT" | grep -q "1234abcd"
    check "printf %x funciona ('1234abcd')" $?

    # ─── Critério 4: Sem reboot/panic/exceção (1 pt) ───
    echo ""
    echo "🛡️  Critério 4: Sem reboot/panic/exceção (1 pt)"

    echo "$QEMU_OUTPUT" | grep -q "OpenSBI"
    check "OpenSBI inicializou" $?

    # Verifica se não houve panic ou exceção
    if echo "$QEMU_OUTPUT" | grep -qi "panic\|exception\|trap"; then
        check "Sem panic/exceção/trap" 1
    else
        check "Sem panic/exceção/trap" 0
    fi

    echo ""
    echo "    Saída do kernel:"
    echo "$QEMU_OUTPUT" | grep -A5 "Hello" | head -10 | sed 's/^/    → /'
else
    echo "  ⚠️  qemu-system-riscv32 não encontrado — pulando testes de execução"
    echo "  Instale com: sudo apt-get install qemu-system-riscv"
fi

# ─── Critério 5: Código organizado, sem libc do host (1 pt) ───
echo ""
echo "📐 Critério 5: Código organizado, sem libc do host (1 pt)"

# Verifica que não usa #include de libc padrão
if grep -rq '#include <std' kernel.c common.c kernel.h common.h 2>/dev/null; then
    check "Sem dependência da libc do host" 1
else
    check "Sem dependência da libc do host" 0
fi

check "Arquivos organizados" 0

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
