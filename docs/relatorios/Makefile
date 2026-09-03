# Makefile para gerenciamento dos relatórios da disciplina (Faculdade / SO)
CC = pdflatex
FLAGS = -interaction=nonstopmode
TEMPLATE_DIR = ../template

REPORTS = r1 r2 r3 r4 r5 r6 r7 r8 r9 r10
.PHONY: all clean clean-all help new $(REPORTS)

# Alvo padrão: compila r1
all: r1

# Compilar um relatório específico (ex: make r1, make r2)
$(REPORTS):
	@if [ ! -f "$@/tex/$@.tex" ]; then \
		echo "Erro: $@/tex/$@.tex não encontrado."; \
		echo "Para criar um novo relatório, use: make new REPORT=$@"; \
		exit 1; \
	fi
	@echo "==> Compilando $@/tex/$@.tex..."
	@cd $@/tex && $(CC) $(FLAGS) $@.tex > /dev/null
	@if grep -q '\\bibliography{' "$@/tex/$@.tex"; then \
		echo "==> Processando BibTeX para $@..."; \
		cd $@/tex && bibtex $@ > /dev/null 2>&1 || true; \
	fi
	@cd $@/tex && $(CC) $(FLAGS) $@.tex > /dev/null
	@cd $@/tex && $(CC) $(FLAGS) $@.tex > /dev/null
	@cp $@/tex/$@.pdf $@/$@.pdf
	@echo "==> Concluído: $@/$@.pdf gerado com sucesso!"

# Criar a pasta e arquivos para o próximo relatório
# Uso: make new REPORT=r3
new:
	@if [ -z "$(REPORT)" ]; then \
		echo "Uso incorreto. Exemplo:"; \
		echo "  make new REPORT=r3"; \
		exit 1; \
	elif [ -f "$(REPORT)/tex/$(REPORT).tex" ]; then \
		echo "Erro: O relatório $(REPORT)/tex/$(REPORT).tex já existe!"; \
		exit 1; \
	else \
		mkdir -p $(REPORT)/tasks $(REPORT)/info $(REPORT)/tex; \
		cp $(TEMPLATE_DIR)/template.tex $(REPORT)/tex/$(REPORT).tex; \
		ln -sf ../../../template/sbc-template.sty $(REPORT)/tex/; \
		ln -sf ../../../template/caption2.sty $(REPORT)/tex/; \
		ln -sf ../../../template/sbc.bst $(REPORT)/tex/; \
		ln -sf ../../../template/sbc.bib $(REPORT)/tex/; \
		echo "==> Criado com sucesso:"; \
		echo "    - $(REPORT)/tasks/ (para enunciados das tarefas)"; \
		echo "    - $(REPORT)/info/ (para notas e materiais de apoio)"; \
		echo "    - $(REPORT)/tex/$(REPORT).tex (a partir do template)"; \
		echo "    - $(REPORT)/tex/ (com links para arquivos de estilo SBC)"; \
		echo "Para compilar: make $(REPORT)"; \
	fi

# Limpar arquivos temporários em todos os relatórios
clean:
	@rm -f r*/tex/*.aux r*/tex/*.log r*/tex/*.bbl r*/tex/*.blg r*/tex/*.out r*/tex/*.toc r*/tex/*.synctex.gz
	@echo "Arquivos intermediários removidos de todos os relatórios."

# Ajuda
help:
	@echo "Comandos disponíveis:"
	@echo "  make               - Compila o relatório r1 (r1/r1.pdf)"
	@echo "  make r1            - Compila o relatório r1"
	@echo "  make r2            - Compila o relatório r2"
	@echo "  make new REPORT=r3 - Cria a estrutura completa de r3 (tasks/, info/, tex/)"
	@echo "  make clean         - Limpa arquivos intermediários dentro de tex/"
