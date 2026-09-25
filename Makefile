# ==============================================================================
# Makefile - Kernel RISC-V 32-bit (SO)
# ==============================================================================

CC        := clang
OBJCOPY   := llvm-objcopy
QEMU      := qemu-system-riscv32

CFLAGS    := -std=c11 -O2 -g3 -Wall -Wextra \
             --target=riscv32-unknown-elf -fuse-ld=lld \
             -fno-stack-protector -ffreestanding -nostdlib \
             -Ikernel -Iuser -Icommon

BUILD_DIR := build
KERNEL_DIR:= kernel
USER_DIR  := user
COMMON_DIR:= common

USER_APP_ELF := $(BUILD_DIR)/user/shell.elf
USER_APP_BIN := $(BUILD_DIR)/user/shell.bin
USER_APP_OBJ := $(BUILD_DIR)/user/shell.bin.o
KERNEL_ELF   := $(BUILD_DIR)/kernel.elf
DIST_PACKAGE := $(BUILD_DIR)/dist/kernel.tar.gz

.PHONY: all run clean dist report help

all: $(KERNEL_ELF)

# Diretórios de build
$(BUILD_DIR)/kernel $(BUILD_DIR)/user $(BUILD_DIR)/dist:
	@mkdir -p $@

# 1. Compilação da aplicação de usuário
$(USER_APP_ELF): $(USER_DIR)/apps/shell.c $(USER_DIR)/lib.c $(COMMON_DIR)/common.c $(USER_DIR)/linker.ld | $(BUILD_DIR)/user
	$(CC) $(CFLAGS) -Wl,-T$(USER_DIR)/linker.ld -Wl,-Map=$(BUILD_DIR)/user/shell.map -o $@ \
		$(USER_DIR)/apps/shell.c $(USER_DIR)/lib.c $(COMMON_DIR)/common.c

# 2. Conversão para binário cru
$(USER_APP_BIN): $(USER_APP_ELF)
	$(OBJCOPY) --set-section-flags .bss=alloc,contents -O binary $< $@

# 3. Encapsulamento em objeto linkável para embutimento no kernel
$(USER_APP_OBJ): $(USER_APP_BIN)
	(cd $(BUILD_DIR)/user && $(OBJCOPY) -Ibinary -Oelf32-littleriscv shell.bin shell.bin.o)

# 4. Compilação e linkagem do kernel
$(KERNEL_ELF): $(KERNEL_DIR)/main.c $(COMMON_DIR)/common.c $(KERNEL_DIR)/linker.ld $(USER_APP_OBJ) | $(BUILD_DIR)/kernel
	$(CC) $(CFLAGS) -Wl,-T$(KERNEL_DIR)/linker.ld -Wl,-Map=$(BUILD_DIR)/kernel/kernel.map -o $@ \
		$(KERNEL_DIR)/main.c $(COMMON_DIR)/common.c $(USER_APP_OBJ)

# Execução no QEMU
run: $(KERNEL_ELF)
	$(QEMU) -machine virt -bios default -nographic -serial mon:stdio --no-reboot -kernel $(KERNEL_ELF)

# Limpeza determinística
clean:
	rm -rf $(BUILD_DIR) *.elf *.bin *.o *.map *.tar *.tar.gz
	@rm -f docs/relatorios/*/*.aux docs/relatorios/*/*.log docs/relatorios/*/*.bbl docs/relatorios/*/*.blg docs/relatorios/*/*.out docs/relatorios/*/*.toc

# Pacote para submissão
dist: $(KERNEL_ELF) | $(BUILD_DIR)/dist
	tar -czf $(DIST_PACKAGE) \
		kernel/main.c kernel/kernel.h kernel/linker.ld \
		user/lib.c user/user.h user/linker.ld user/apps/shell.c \
		common/common.c common/common.h \
		Makefile run.sh \
		$(KERNEL_ELF)
	@echo "==> Pacote de submissão gerado: $(DIST_PACKAGE)"

# Compilação de relatórios (ex: make report REPORT=r2)
REPORT ?= r2
report:
	@if [ ! -f "docs/relatorios/$(REPORT)/main.tex" ]; then \
		echo "Erro: docs/relatorios/$(REPORT)/main.tex não encontrado."; \
		exit 1; \
	fi
	@echo "==> Compilando relatório $(REPORT)..."
	@cd docs/relatorios/$(REPORT) && \
		TEXINPUTS=.:../../template: pdflatex -interaction=nonstopmode main.tex > /dev/null && \
		(bibtex main > /dev/null 2>&1 || true) && \
		TEXINPUTS=.:../../template: pdflatex -interaction=nonstopmode main.tex > /dev/null && \
		TEXINPUTS=.:../../template: pdflatex -interaction=nonstopmode main.tex > /dev/null && \
		cp main.pdf $(REPORT).pdf
	@echo "==> Concluído: docs/relatorios/$(REPORT)/$(REPORT).pdf gerado."

help:
	@echo "Alvos disponíveis:"
	@echo "  make              - Compila kernel e aplicação (gera build/kernel.elf)"
	@echo "  make run          - Compila e executa no QEMU"
	@echo "  make clean        - Remove diretório build/ e arquivos temporários"
	@echo "  make dist         - Gera o pacote .tar.gz de submissão em build/dist/"
	@echo "  make report       - Compila o relatório especificado (ex: make report REPORT=r2)"
