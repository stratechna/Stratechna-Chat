#!/bin/bash
# Aplica a marca Stratechna a uma organização do Stratechna Chat.
#
# Usa a API HTTP documentada e não os internos do Django: `PATCH /api/v1/realm`
# e `POST /api/v1/realm/icon|logo` são contrato público e mantêm-se entre
# versões; um `manage.py shell` a mexer em modelos parte-se na próxima
# actualização, e parte-se em silêncio.
#
# O NOME da organização é o nome do CLIENTE, não o do produto: no Zulip o realm
# é a organização, e é esse nome que aparece nos convites e nos emails que saem.
# O produto identifica-se pelo logótipo, que é o mesmo em todas — a regra da
# casa, «a marca não se traduz nem se reparte».
#
# A chave nunca vai em argumentos (ficaria visível num `ps`): vai num ficheiro
# no formato netrc, que o curl lê e que é apagado no fim.
#
# Uso: marca/aplicar.sh <host> <ficheiro-netrc> "<nome da organização>"
#   host   chat.orbit.stratechna.com  ou  <cliente>.chat.orbit.stratechna.com
#
# O ficheiro netrc tem uma linha:  machine <host> login <email> password <chave>
set -euo pipefail

HOST=${1:?uso: aplicar.sh <host> <ficheiro-netrc> "<nome da organizacao>"}
NETRC=${2:?falta o ficheiro netrc}
NOME=${3:?falta o nome da organização}
BASE="https://${HOST}/api/v1"
DIR=$(cd "$(dirname "$0")" && pwd)

[ -r "$NETRC" ] || { echo "netrc ilegível: $NETRC"; exit 1; }
C=(curl -sS --netrc-file "$NETRC")

falhou=0
verificar() {
  local etapa=$1 resposta=$2
  if printf '%s' "$resposta" | grep -q '"result":"success"'; then
    echo "  ok: $etapa"
  else
    echo "  FALHA: $etapa -> $(printf '%s' "$resposta" | head -c 200)"
    falhou=1
  fi
}

echo "== organização em ${HOST} =="

# Nome e descrição visíveis no separador, nos convites e nos emails.
verificar "nome da organização" "$("${C[@]}" -X PATCH "$BASE/realm" \
  --data-urlencode "name=${NOME}")"
verificar "descrição" "$("${C[@]}" -X PATCH "$BASE/realm" \
  --data-urlencode 'description=Conversas internas da equipa — Stratechna Chat, parte do Stratechna Orbit')"

# O ícone é o quadrado pequeno (separador, listas); os logótipos são a barra
# lateral, e são dois porque o Zulip tem tema claro e escuro.
verificar "ícone" "$("${C[@]}" -X POST "$BASE/realm/icon" \
  -F "file=@$DIR/ficheiros/chat-icone.png")"
verificar "logótipo (tema claro)" "$("${C[@]}" -X POST "$BASE/realm/logo" \
  -F "file=@$DIR/ficheiros/chat-logo.png" -F 'night=false')"
verificar "logótipo (tema escuro)" "$("${C[@]}" -X POST "$BASE/realm/logo" \
  -F "file=@$DIR/ficheiros/chat-logo-escuro.png" -F 'night=true')"

# PROVA: lê-se o que o servidor devolve, não o que julgamos ter enviado.
#
# Não há `GET /api/v1/realm` — a primeira versão disto pedia-o, recebia um erro,
# e dava cinco falhas sobre uma marca que estava aplicada. O estado do realm
# obtém-se pelo `register`, que é o mesmo pedido que o cliente web faz ao abrir.
estado=$("${C[@]}" -X POST "$BASE/register" \
  --data-urlencode 'event_types=["realm"]' || true)
for campo in realm_icon_url realm_logo_url realm_night_logo_url; do
  printf '%s' "$estado" | grep -q "\"$campo\":\"[^\"]*/user_avatars/\|\"$campo\":\"[^\"]*realm/" \
    || { echo "  FALHA: $campo continua a apontar para o ficheiro de origem"; falhou=1; }
done
printf '%s' "$estado" | grep -qF "\"realm_name\":\"${NOME}\"" \
  || { echo "  FALHA: o nome da organização não ficou gravado"; falhou=1; }

echo
if [ $falhou -ne 0 ]; then
  echo "A marca NÃO ficou completa — ver as falhas acima."
  exit 1
fi
echo "Marca aplicada a ${HOST} (${NOME})."
