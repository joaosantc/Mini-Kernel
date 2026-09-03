#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

TEMPLATE_DIR="../template"
cmd="${1:-r1}"

case "$cmd" in
    clean)
        rm -f r*/tex/*.aux r*/tex/*.log r*/tex/*.bbl r*/tex/*.blg r*/tex/*.out r*/tex/*.toc r*/tex/*.synctex.gz
        echo "Arquivos intermediários removidos."
        ;;
    new)
        name="$2"
        if [ -z "$name" ]; then
            echo "Uso: ./build.sh new <nome> (ex: ./build.sh new r3)"
            exit 1
        fi
        if [ -f "$name/tex/$name.tex" ]; then
            echo "Erro: O relatório $name/tex/$name.tex já existe!"
            exit 1
        fi
        mkdir -p "$name/tasks" "$name/info" "$name/tex"
        cp "$TEMPLATE_DIR/template.tex" "$name/tex/$name.tex"
        ln -sf ../../../template/sbc-template.sty "$name/tex/"
        ln -sf ../../../template/caption2.sty "$name/tex/"
        ln -sf ../../../template/sbc.bst "$name/tex/"
        ln -sf ../../../template/sbc.bib "$name/tex/"
        echo "==> Estrutura $name criada com sucesso."
        ;;
    *)
        report="${cmd%/}"
        tex_file="$report/tex/$report.tex"
        if [ ! -f "$tex_file" ]; then
            echo "Erro: $tex_file não encontrado."
            echo "Uso:"
            echo "  ./build.sh <relatorio>  (ex: ./build.sh r1)"
            echo "  ./build.sh new <nome>   (ex: ./build.sh new r3)"
            echo "  ./build.sh clean"
            exit 1
        fi
        echo "==> Compilando $tex_file..."
        (
            cd "$report/tex"
            pdflatex -interaction=nonstopmode "$report.tex" > /dev/null
            if grep -q '\\bibliography{' "$report.tex"; then
                echo "==> Processando BibTeX..."
                bibtex "$report" > /dev/null 2>&1 || true
            fi
            pdflatex -interaction=nonstopmode "$report.tex" > /dev/null
            pdflatex -interaction=nonstopmode "$report.tex" > /dev/null
            cp "$report.pdf" ..
        )
        echo "==> Concluído: $report/$report.pdf gerado com sucesso!"
        ;;
esac
