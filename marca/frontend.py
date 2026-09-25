#!/usr/bin/env python3
"""A marca na app do Chat — a que se vê depois de entrar.

Uso: frontend.py <pasta-locale> <pasta-pacotes> <nome> <lingua> [<lingua>...]

Durante algum tempo achou-se que isto não se podia fazer: o nome do fabricante
estaria «em pacotes de webpack com hash de conteúdo», e uma camada de texto
partir-se-ia em silêncio a cada actualização. A primeira parte é verdade; a
conclusão não era. O que está nos pacotes são **chaves de tradução** — pares
`id` / `defaultMessage` — e o texto que o utilizador lê vem do
`locale/<lingua>/translations.json`, que é um ficheiro de dados simples, do
mesmo tipo dos catálogos `.po` do lado do servidor.

Por isso NÃO se toca nos pacotes. Mexer num `id` é o mesmo que mexer num
`msgid`: deita fora a tradução em silêncio e o utilizador passa a ver inglês.

Duas coisas, então:

  1. nas traduções que existem, troca-se o nome (só do lado do VALOR);
  2. para as chaves que mencionam o fabricante e que ainda **não** têm tradução,
     escreve-se uma — com o texto inglês já com o nosso nome. Continua em
     inglês, como já estava, mas deixa de anunciar outra marca.
"""

import json
import pathlib
import re
import sys


def chaves_dos_pacotes(pasta: pathlib.Path) -> dict[str, str]:
    """`id` → `defaultMessage`, só das mensagens que nomeiam o fabricante."""
    achadas: dict[str, str] = {}
    padrao = re.compile(
        r'id:"((?:[^"\\]|\\.)*)",defaultMessage:"((?:[^"\\]|\\.)*)"')
    for js in sorted(pasta.glob("*.js")):
        if js.name.endswith(".map"):
            continue
        texto = js.read_text(encoding="utf-8", errors="replace")
        for m in padrao.finditer(texto):
            ident, omissao = m.group(1), m.group(2)
            if "Zulip" in ident or "Zulip" in omissao:
                achadas[ident] = omissao
    return achadas


def tratar(ficheiro: pathlib.Path, das_apps: dict[str, str], novo: str) -> tuple[int, int]:
    d = json.loads(ficheiro.read_text(encoding="utf-8"))
    trocadas = 0
    for chave, valor in list(d.items()):
        if isinstance(valor, str) and "Zulip" in valor:
            d[chave] = valor.replace("Zulip", novo)
            trocadas += 1
    acrescentadas = 0
    for ident, omissao in das_apps.items():
        if d.get(ident):
            continue
        d[ident] = (omissao or ident).replace("Zulip", novo).replace("\\n", "\n")
        acrescentadas += 1
    ficheiro.write_text(json.dumps(d, ensure_ascii=False, indent=0, sort_keys=True),
                        encoding="utf-8")
    return trocadas, acrescentadas


def main() -> int:
    locale = pathlib.Path(sys.argv[1])
    pacotes = pathlib.Path(sys.argv[2])
    novo = sys.argv[3]
    das_apps = chaves_dos_pacotes(pacotes)
    print(f"chaves com o nome do fabricante nos pacotes: {len(das_apps)}")
    if not das_apps:
        print("ERRO: nenhuma — a forma das mensagens mudou?")
        return 1
    total = 0
    for lingua in sys.argv[4:]:
        f = locale / lingua / "translations.json"
        if not f.exists():
            print(f"  {lingua}: sem ficheiro")
            continue
        t, a = tratar(f, das_apps, novo)
        print(f"  {lingua}: {t} traduções mudadas, {a} acrescentadas")
        total += t + a
    if not total:
        print("ERRO: nada mudou em língua nenhuma")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
