#!/usr/bin/env python3
"""O texto de reserva, dentro dos pacotes — o que se lê quando não há tradução.

Uso: pacotes.py <pasta-de-pacotes> <nome>

Cada mensagem da app vive nos pacotes como um par:

    {id:"Welcome to Zulip!", defaultMessage:"Welcome to Zulip!"}

O `id` é a CHAVE com que se procura a tradução. Mexer-lhe é o mesmo que mexer
num `msgid`: a procura deixa de encontrar e o utilizador passa a ver a chave em
bruto. Fica intocado, e é essa a razão por que os pacotes tinham ficado de fora.

O `defaultMessage` é outra coisa: é só o texto de reserva, lido quando a língua
não tem tradução para aquela chave. Em português não é lido nunca — as
traduções cobrem tudo. Em INGLÊS é o que se lê, e era por isso que sobravam
trinta frases com o nome do fabricante. Mudá-lo não parte procura nenhuma.

Também se trata o título da janela, que não é mensagem nenhuma: é uma soma de
pedaços, `<assunto> - <organização> - Zulip`.

ARMADILHA, e custou o mesmo engano duas vezes na casa (o Docs, a 10-09-2026):
o nginx serve os ficheiros PRÉ-COMPRIMIDOS quando o browser aceita gzip, e
aceitam todos. Editar o `.js` e deixar o `.js.gz` antigo não muda nada no
browser — e não dá erro nenhum. Cada ficheiro tocado tem de ter o seu `.gz`
refeito.
"""

import gzip
import pathlib
import re
import shutil
import sys

# `defaultMessage:"…"`, a aguentar aspas escapadas lá dentro.
RESERVA = re.compile(r'(defaultMessage:")((?:[^"\\]|\\.)*)(")')
# O título da janela: `… + " - Zulip"`, texto literal e não chave.
TITULO = re.compile(r'(realm_name\s*\+\s*")( - Zulip)(")')


def tratar(js: pathlib.Path, novo: str) -> tuple[int, int]:
    texto = original = js.read_text(encoding="utf-8", errors="surrogateescape")

    reservas = 0

    def troca_reserva(m: re.Match) -> str:
        nonlocal reservas
        if "Zulip" not in m.group(2):
            return m.group(0)
        reservas += 1
        return m.group(1) + m.group(2).replace("Zulip", novo) + m.group(3)

    texto = RESERVA.sub(troca_reserva, texto)
    texto, titulos = TITULO.subn(lambda m: m.group(1) + " - " + novo + m.group(3), texto)

    if texto == original:
        return 0, 0

    js.write_text(texto, encoding="utf-8", errors="surrogateescape")
    # O pré-comprimido tem de acompanhar, senão o browser continua a ler o antigo.
    gz = js.with_suffix(js.suffix + ".gz")
    if gz.exists():
        with open(js, "rb") as entra, gzip.open(gz, "wb", compresslevel=9) as sai:
            shutil.copyfileobj(entra, sai)
    return reservas, titulos


def main() -> int:
    pasta = pathlib.Path(sys.argv[1])
    novo = sys.argv[2]
    total_r = total_t = ficheiros = 0
    for js in sorted(pasta.glob("*.js")):
        if js.name.endswith(".map"):
            continue
        r, t = tratar(js, novo)
        if r or t:
            ficheiros += 1
            total_r += r
            total_t += t
    print(f"pacotes tocados: {ficheiros} | textos de reserva: {total_r} | titulos: {total_t}")
    if not total_r:
        print("ERRO: nenhum texto de reserva com o nome do fabricante — a forma mudou?")
        return 1
    if not total_t:
        print("AVISO: o titulo da janela nao foi encontrado na forma esperada")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
