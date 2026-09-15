# Stratechna Chat

Conversas internas do Stratechna Orbit: canais gerais, grupos e mensagens
privadas, com um administrador por organização. É o
[Zulip](https://github.com/zulip/zulip) com a marca Stratechna.

## Porque é que aqui NÃO há imagem com marca

Nos outros produtos (`Stratechna-Social`, `Stratechna-Meet`) a marca entra numa
camada de imagem, porque a superfície é pequena e estável — meia dúzia de
ficheiros de configuração e alguns ficheiros de idioma.

**No Zulip isso seria um erro.** O nome do produto está espalhado por milhares
de referências no frontend, e o que o browser recebe são *bundles* de webpack
com o nome baseado no conteúdo: mudar um texto muda o hash de todos os ficheiros
que o incluem. Uma camada que reescrevesse strings partir-se-ia a cada
actualização, e partir-se-ia **em silêncio** — que é a pior maneira.

O Zulip resolve isto de outra forma, e é a forma suportada: **a marca é por
organização, em runtime.** Nome, ícone, logótipo claro e escuro são definições
do realm, sobrevivem a qualquer actualização, e podem ser diferentes de cliente
para cliente — que é precisamente o que um produto multi-organização precisa.

É isso que o `marca/aplicar.sh` faz.

## Uso

```bash
marca/aplicar.sh <subdominio> <chave-api-do-admin>
```

Por exemplo, `marca/aplicar.sh stratechna zulip_api_key...`. A chave obtém-se em
*Definições pessoais → Conta e privacidade → Chave de API* de uma conta com
perfil de administrador da organização.

O guião usa a **API HTTP documentada** e não os internos do Django, de propósito:
os endpoints `PATCH /api/v1/realm` e `POST /api/v1/realm/icon` são contrato
público e mantêm-se entre versões; `manage.py shell` a mexer em modelos não.

## Ficheiros

| Ficheiro | Papel |
|---|---|
| `marca/aplicar.sh` | aplica nome, ícone e logótipos a uma organização |
| `marca/ficheiros/` | os desenhos (ícone e logótipo claro/escuro) |

## O que fica de fora

A instalação e a configuração de produção vivem no `docker-compose.yml` do Orbit
(`/opt/orbit/compose/chat`). Dois pontos que custaram um arranque falhado cada e
que estão lá documentados: o `LOADBALANCER_IPS` é **obrigatório** atrás do
Traefik (sem ele o Zulip devolve 500 a tudo), e o memcached com SASL exige a base
de utilizadores criada antes do arranque.
