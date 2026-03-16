#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
manuscript_file="$repo_root/MANUSCRIPT.md"
cover_file="$repo_root/cover.png"
output_file="$repo_root/What-It-Feels-Like-to-Be-Us.pdf"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

if [[ ! -f "$manuscript_file" ]]; then
  printf 'Missing manuscript: %s\n' "$manuscript_file" >&2
  exit 1
fi

if [[ ! -f "$cover_file" ]]; then
  printf 'Missing cover image: %s\n' "$cover_file" >&2
  exit 1
fi

require_command pandoc
require_command pdflatex

tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
}

trap cleanup EXIT

body_file="$tmp_dir/body.md"
cover_tex="$tmp_dir/cover.tex"
style_tex="$tmp_dir/style.tex"

awk '
  BEGIN {
    title_skipped = 0
    author_skipped = 0
    frontmatter_written = 0
  }

  !title_skipped && /^# / {
    title_skipped = 1
    next
  }

  title_skipped && !author_skipped && /^A novel by / {
    author_skipped = 1
    next
  }

  title_skipped && !frontmatter_written && $0 == "" {
    next
  }

  !frontmatter_written {
    print "\\booktitlepage"
    print ""
    frontmatter_written = 1
  }

  /^## / {
    print "\\actpage{" substr($0, 4) "}"
    print ""
    next
  }

  /^### / {
    print "# " substr($0, 5)
    next
  }

  {
    print
  }
' "$manuscript_file" > "$body_file"

cat > "$cover_tex" <<EOF
\\newgeometry{paperwidth=6in,paperheight=9in,margin=0in}
\\thispagestyle{empty}
\\noindent\\includegraphics[width=\\paperwidth,height=\\paperheight]{\\detokenize{$cover_file}}
\\restoregeometry
\\clearpage
EOF

cat > "$style_tex" <<'EOF'
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage{graphicx}
\usepackage{geometry}
\usepackage{microtype}
\usepackage{mathpazo}
\usepackage{setspace}
\usepackage{xcolor}
\usepackage{titlesec}
\usepackage{fancyhdr}
\usepackage{emptypage}
\usepackage{hyperref}
\usepackage{bookmark}

\definecolor{ink}{HTML}{1C1816}
\definecolor{accent}{HTML}{7A6552}
\definecolor{rulecolor}{HTML}{D8D0C8}

\geometry{
  paperwidth=6in,
  paperheight=9in,
  top=0.85in,
  bottom=0.9in,
  left=0.85in,
  right=0.8in,
  headheight=14pt,
  headsep=0.18in,
  footskip=0.38in
}

\setstretch{1.08}
\setlength{\parindent}{1.25em}
\setlength{\parskip}{0pt}
\setlength{\emergencystretch}{2em}
\widowpenalty=10000
\clubpenalty=10000
\displaywidowpenalty=10000
\raggedbottom

\hypersetup{
  pdftitle={What It Feels Like to Be Us},
  pdfauthor={Joshua Szepietowski},
  colorlinks=true,
  linkcolor=ink,
  urlcolor=accent,
  citecolor=accent
}

\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\small\itshape What It Feels Like to Be Us}
\fancyhead[R]{\small\itshape \nouppercase{\leftmark}}
\fancyfoot[C]{\small\thepage}
\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0pt}

\fancypagestyle{plain}{
  \fancyhf{}
  \fancyfoot[C]{\small\thepage}
  \renewcommand{\headrulewidth}{0pt}
  \renewcommand{\footrulewidth}{0pt}
}

\makeatletter
\renewcommand{\chaptermark}[1]{\markboth{#1}{}}
\makeatother

\titleformat{\part}[display]
  {\normalfont\Huge\bfseries\filcenter\color{ink}}
  {}
  {0pt}
  {}
  [\vspace{0.75em}\color{rulecolor}\titlerule]

\titlespacing*{\part}{0pt}{0.22\textheight}{2.5\baselineskip}

\titleformat{\chapter}[display]
  {\normalfont\huge\bfseries\filcenter\color{ink}}
  {}
  {0pt}
  {}
  [\vspace{0.75em}\color{rulecolor}\titlerule]

\titlespacing*{\chapter}{0pt}{0pt}{2.5\baselineskip}

\newcommand{\booktitlepage}{%
  \frontmatter
  \thispagestyle{empty}%
  \vspace*{0.24\textheight}%
  \begin{center}%
    {\fontsize{28}{34}\selectfont\bfseries What It Feels Like to Be Us\par}%
    \vspace{1.4em}%
    {\large A novel by\par}%
    \vspace{0.5em}%
    {\Large Joshua Szepietowski\par}%
  \end{center}%
  \vfill
  \clearpage
  \mainmatter
}

\newcommand{\actpage}[1]{%
  \part*{#1}%
  \thispagestyle{empty}%
  \markboth{#1}{#1}%
}
EOF

pandoc "$body_file" \
  --from markdown+raw_tex \
  --to pdf \
  --standalone \
  --pdf-engine=pdflatex \
  --include-before-body="$cover_tex" \
  --include-in-header="$style_tex" \
  --resource-path="$repo_root" \
  --variable=documentclass:book \
  --variable=classoption:oneside \
  --variable=classoption:openany \
  --variable=fontsize:11pt \
  --pdf-engine-opt=-interaction=nonstopmode \
  --pdf-engine-opt=-halt-on-error \
  --output "$output_file"

printf 'Wrote %s\n' "$output_file"