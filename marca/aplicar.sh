#!/bin/bash
# Aplica a marca Stratechna a uma organização do Stratechna Chat.
#
# Usa a API HTTP documentada e não os internos do Django: `PATCH /api/v1/realm`
# e `POST /api/v1/realm/icon` são contrato público e mantêm-se entre versões;
# um `manage.py shell` a mexer em modelos parte-se na próxima actualização, e
# parte-se em silêncio.
#
# Uso: marca/aplicar.sh <subdominio> <chave-api-do-admin> [email-do-admin]
set -euo pipefail

SUB=${1:?uso: aplicar.sh <subdominio> <chave-api> [email]}
CHAVE=${2:?falta a chave de API}
EMAIL=${3:-}
BASE="https://${SUB}.chat.orbit.stratechna.com/api/v1"
DIR=$(cd "$(dirname "$0")" && pwd)

# A API do Zulip autentica-se em Basic com <email>:<chave>. Sem o email dado,
# pergunta-se à própria API quem é o dono da chave.
if [ -z "$EMAIL" ]; then
  EMAIL=$(curl -sS -u "dummy:$CHAVE" "$BASE/users/me" 2>/dev/null |
          python3 -c 'import json,sys; print(json.load(sys.stdin).get("email",""))' || true)
  [ -n "$EMAIL" ] || { echo "Não consegui descobrir o email da chave — passa-o como 3.º argumento."; exit 1; }
fi
AUTH=(-u "$EMAIL:$CHAVE")

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

echo "== organização em ${SUB}.chat.orbit.stratechna.com =="

# Nome e descrição visíveis no separador, nos convites e nos emails.
verificar "nome da organização" "$(curl -sS "${AUTH[@]}" -X PATCH "$BASE/realm" \
  --data-urlencode 'name=Stratechna Chat' \
  --data-urlencode 'description=Conversas internas da equipa — Stratechna Orbit')"

# O ícone é o quadrado pequeno (separador, listas); os logótipos são a barra
# lateral, e são dois porque o Zulip tem tema claro e escuro.
verificar "ícone" "$(curl -sS "${AUTH[@]}" -X POST "$BASE/realm/icon" \
  -F "file=@$DIR/ficheiros/chat-icone.png")"
verificar "logótipo (tema claro)" "$(curl -sS "${AUTH[@]}" -X POST "$BASE/realm/logo" \
  -F "file=@$DIR/ficheiros/chat-logo.png" -F 'night=false')"
verificar "logótipo (tema escuro)" "$(curl -sS "${AUTH[@]}" -X POST "$BASE/realm/logo" \
  -F "file=@$DIR/ficheiros/chat-logo-escuro.png" -F 'night=true')"

echo
if [ $falhou -ne 0 ]; then
  echo "A marca NÃO ficou completa — ver as falhas acima."
  exit 1
fi
echo "Marca aplicada a ${SUB}."
