#!/usr/bin/env python3
"""Gera uma página de grill (perguntas com escolhas, recomendada marcada, campo aberto e botão
"Copiar respostas") a partir de um ficheiro de perguntas.

Uso: python3 tools/grill_page.py <perguntas.py> <saida.html>

O ficheiro de perguntas define: ROUND (int), DATE (str), TITLE (str), INTRO (str, HTML) e
Q = [(titulo, contexto, [(rotulo, detalhe, recomendada), ...], ["check"])].
O estilo vem de docs/design/grill-ronda2.html (modelo)."""
import html, os, re, runpy, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATE = os.path.join(ROOT, "docs/design/grill-ronda2.html")

def esc(s):
    return html.escape(s, quote=True)

def blocks(Q):
    out = []
    for i, q in enumerate(Q, 1):
        title, ctx, opts = q[0], q[1], q[2]
        kind = "checkbox" if len(q) > 3 else "radio"
        rows = []
        for lab, det, rec in opts:
            val = lab + (f" — {det}" if det else "")
            rows.append(
                f'<label class="opt"><input type="{kind}" name="q{i}" value="{esc(val)}"{" checked" if rec else ""}>'
                f'<span><b>{esc(lab)}</b>{"<span class=rec>recomendado</span>" if rec else ""}'
                f'{f"<small>{esc(det)}</small>" if det else ""}</span></label>')
        out.append(f'''<fieldset data-q="Q{i} {esc(title)}">
  <legend><div class="qh"><span class="qn">Q{i}</span><span class="qt">{esc(title)}</span></div></legend>
  {f'<p class="ctx">{esc(ctx)}</p>' if ctx else ''}
  <div class="opts">{''.join(rows)}</div>
  <textarea name="q{i}x" placeholder="Resposta aberta (opcional): completa ou substitui a escolha"></textarea>
</fieldset>''')
    return "\n".join(out)

def main():
    spec = runpy.run_path(sys.argv[1])
    Q, rnd = spec["Q"], spec["ROUND"]
    t = open(TEMPLATE, encoding="utf-8").read()
    t = re.sub(r"<title>.*?</title>", f"<title>Correio Cósmico · Grill · Ronda {rnd}</title>", t, flags=re.S)
    t = re.sub(r"<header>.*?</header>", f'''<header>
 <div class="tag">Grill · Ronda {rnd} · {esc(spec["DATE"])}</div>
 <h1>{esc(spec["TITLE"])}</h1>
 <p>{spec["INTRO"].replace("QCOUNT", str(len(Q)))}</p>
</header>''', t, flags=re.S)
    t = re.sub(r'<form id="f">.*?</form>', '<form id="f">\n' + blocks(Q) + '\n</form>', t, flags=re.S)
    t = re.sub(r'"Grill Correio Cósmico, ronda \d+:"', f'"Grill Correio Cósmico, ronda {rnd}:"', t)
    open(sys.argv[2], "w", encoding="utf-8").write(t)
    print("ok", len(Q), "perguntas")

main()
