# Relatórios da Disciplina (SO)

Esta pasta agrupa todos os relatórios práticos periódicos da disciplina (um relatório a cada 5 trabalhos).

---

## 📁 Estrutura

```text
docs/
├── relatorios/
│   ├── r1/                     <- Entrega 1 (Trabalhos 1 a 5)
│   │   ├── tasks/              <- Enunciados das tarefas 1 a 5
│   │   ├── info/               <- Notas de aula e guias das tarefas 1 a 5
│   │   ├── r1.pdf              <- PDF final compilado da entrega
│   │   └── tex/                <- Pasta com todos os arquivos do template/LaTeX
│   │       ├── r1.tex          <- Código-fonte LaTeX do relatório
│   │       ├── sbc-template.sty
│   │       ├── caption2.sty
│   │       ├── sbc.bst
│   │       └── sbc.bib
│   ├── r2/                     <- Entrega 2 (Trabalhos 6 a 10)
│   │   ├── tasks/
│   │   ├── info/
│   │   ├── r2.pdf
│   │   └── tex/
│   │       └── r2.tex
│   ├── Makefile                <- Automação de compilação
│   ├── build.sh                <- Script auxiliar em Bash
│   └── README.md
└── template/                   <- Modelo oficial mestre da SBC
    ├── template.tex
    ├── sbc-template.sty
    ├── caption2.sty
    ├── sbc.bst
    └── sbc.bib
```

---

## 🚀 Como Usar

### 1. Criar a estrutura para o próximo relatório (ex: `r3`)
Execute na pasta `docs/relatorios/`:

```bash
make new REPORT=r3
```
*(ou `./build.sh new r3`)*

Isso criará automaticamente:
- A pasta `r3/` contendo `tasks/`, `info/` e `tex/`;
- O arquivo `r3/tex/r3.tex` baseado no template com seus dados preenchidos;
- Os links simbólicos necessários dentro de `r3/tex/` para os estilos da SBC.

### 2. Compilar um relatório
```bash
# Compilar r1 (gera r1/r1.pdf)
make r1

# Compilar r2 (gera r2/r2.pdf)
make r2

# Ou usando o script auxiliar:
./build.sh r1
./build.sh r2
```

### 3. Limpeza de arquivos intermediários
Para remover arquivos temporários (`.aux`, `.log`, etc.) gerados dentro de `tex/`:

```bash
make clean
# ou
./build.sh clean
```
