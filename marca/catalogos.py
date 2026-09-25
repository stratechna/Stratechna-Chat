#!/usr/bin/env python3
"""Troca o nome do fabricante DENTRO das traduções, e só aí.

Uso: catalogos.py <pasta-locale> <nome> <lingua> [<lingua>...]

Um ficheiro .po é uma sequência de blocos. O que se pode tocar é o `msgstr` — o
lado traduzido. O `msgid` é a chave com que o Django procura a frase: mexer-lhe
deita a tradução fora em silêncio, e o utilizador passa a ver o texto em inglês.

Porque não um `sed`: um `msgstr` longo parte-se em várias linhas, e as
continuações são linhas que começam por aspas, indistinguíveis das continuações
de um `msgid`. Um `sed` em `^msgstr` apanha a primeira linha e deixa as outras —
foi o que aconteceu à primeira tentativa, e sobrou «a conta Zulip» no meio de um
email já marcado. Aqui segue-se o estado do bloco, que é a única forma de saber
de que lado da frase estamos.
"""

import pathlib
import sys


def tratar(caminho: pathlib.Path, antigo: str, novo: str) -> int:
    trocas = 0
    saida = []
    dentro_de_msgstr = False
    for linha in caminho.read_text(encoding="utf-8").splitlines(keepends=True):
        nu = linha.lstrip()
        if nu.startswith(("msgid", "msgctxt", "msgid_plural")):
            dentro_de_msgstr = False
        elif nu.startswith("msgstr"):
            dentro_de_msgstr = True
        elif not nu.startswith('"'):
            # comentário, linha em branco, referência: fecha o bloco
            dentro_de_msgstr = False
        if dentro_de_msgstr and antigo in linha:
            trocas += linha.count(antigo)
            linha = linha.replace(antigo, novo)
        saida.append(linha)
    if trocas:
        caminho.write_text("".join(saida), encoding="utf-8")
    return trocas


def main() -> int:
    base = pathlib.Path(sys.argv[1])
    novo = sys.argv[2]
    total = 0
    for lingua in sys.argv[3:]:
        po = base / lingua / "LC_MESSAGES" / "django.po"
        if not po.exists():
            print(f"  {lingua}: sem catálogo")
            continue
        n = tratar(po, "Zulip", novo)
        total += n
        print(f"  {lingua}: {n} trocas")
    if not total:
        print("ERRO: nenhuma tradução com o nome do fabricante — mudou alguma coisa?")
        return 1
    print(f"traduções tratadas: {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
