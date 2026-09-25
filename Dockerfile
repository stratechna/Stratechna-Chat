# Stratechna Chat — camada de marca por cima do Zulip.
#
# Porque é que esta camada existe, quando a regra era não a haver
# ---------------------------------------------------------------
# A 16-09-2026 decidiu-se não marcar o Zulip, com o argumento de que o nome do
# fabricante estaria «em pacotes de webpack com hash de conteúdo» e que uma
# camada de texto se partiria em silêncio a cada actualização. A primeira parte
# é verdade; a conclusão não era, e a decisão foi revista a 25-09.
#
# O que está nos pacotes são CHAVES DE TRADUÇÃO — pares `id`/`defaultMessage` —
# e o texto que o utilizador lê vem de ficheiros de dados: `translations.json`
# do lado da app, catálogos `.po` do lado do servidor. São do mesmo tipo dos
# catálogos que já se tratam em qualquer outra app, e não se partem sozinhos:
# se a chave desaparecer, a construção falha.
#
# Por isso NÃO se toca nos pacotes. Mexer num `id` é o mesmo que mexer num
# `msgid`: deita fora a tradução em silêncio e o utilizador passa a ver inglês.
# Toca-se no que é texto: traduções, molduras, títulos e o correio.
#
# Regra da casa: cada substituição verifica o seu padrão antes, e a construção
# falha se o padrão tiver desaparecido. Uma marca que some numa actualização sem
# ninguém dar por isso é pior do que uma construção vermelha.
ARG ZULIP_VERSION=11.2-0
FROM zulip/docker-zulip:${ZULIP_VERSION}

ARG NOME="Stratechna Chat"
# 4. A app, depois de entrar.
#
# As traduções que existem levam o nome novo; as chaves que mencionam o
# fabricante e ainda não têm tradução ganham uma, com o texto inglês já com o
# nosso nome — continua em inglês, como já estava, mas deixa de anunciar outra
# marca.
COPY marca/frontend.py /tmp/frontend.py

RUN set -eu; \
    python3 /tmp/frontend.py \
      /home/zulip/deployments/current/locale \
      /home/zulip/prod-static/webpack-bundles \
      "${NOME}" pt pt_PT pt_BR; \
    rm -f /tmp/frontend.py

# 5. O texto de reserva dentro dos pacotes.
#
# O `id` de cada mensagem é a chave de procura e fica INTOCADO. O
# `defaultMessage` é o texto que se lê quando a língua não tem tradução — em
# português nunca é lido, em inglês é sempre. Era o que faltava para fechar as
# trinta frases.
#
# O nginx serve os ficheiros pré-comprimidos (`gzip_static on`), por isso cada
# pacote tocado tem o seu `.gz` refeito — a mesma armadilha que a 10-09 deixou
# o Docs a dizer «Paperless-ngx» num `.gz` que ninguém regenerava.
COPY marca/pacotes.py /tmp/pacotes.py

RUN set -eu; \
    python3 /tmp/pacotes.py /home/zulip/prod-static/webpack-bundles "${NOME}"; \
    rm -f /tmp/pacotes.py

# 6. Os títulos das páginas.
#
# Quase todos terminam em « | Zulip»; a moldura da app usa «<organização> -
# Zulip», e as três molduras do correio dizem só «Zulip». É texto literal, não é
# chave de tradução — e por isso uma regra só, sobre a terminação, chega para
# todos: um passo à parte para o correio tornou-se redundante e saiu. Trata-se a terminação, que
# é o que as duas formas têm em comum — a primeira tentativa tratou as duas
# formas à mão e deixou três ficheiros para trás, e foi a verificação que o
# apanhou.
RUN set -eu; \
    cd /home/zulip/deployments/current/templates; \
    antes=$(grep -rl "Zulip</title>" . 2>/dev/null | wc -l); \
    [ "$antes" -ge 1 ] || { echo "ERRO: nenhum titulo tinha o nome do fabricante"; exit 1; }; \
    grep -rlZ "Zulip</title>" . 2>/dev/null \
      | xargs -0 sed -i "s#Zulip</title>#${NOME}</title>#g"; \
    sobra=$(grep -rl "Zulip</title>" . 2>/dev/null | wc -l); \
    echo "titulos tratados: $antes (sobram $sobra)"; \
    [ "$sobra" = "0" ] || { echo "ERRO: ainda ha titulos com o nome do fabricante"; exit 1; }

USER root

# 1. O nome de quem assina o correio.
#
# O `INSTALLATION_NAME` (que se define por SETTING_) cobre só os emails de
# SEGURANÇA. Todos os outros — convites, reposição de palavra-passe,
# notificações — caem num `from_name = "Zulip"` escrito no código. Era por isso
# que a caixa de entrada dizia «Zulip» mesmo com a organização toda marcada.
RUN set -eu; \
    F=/home/zulip/deployments/current/zerver/lib/send_email.py; \
    grep -q 'from_name = "Zulip"' "$F" || { echo "ERRO: o remetente por omissao mudou de forma"; exit 1; }; \
    sed -i 's/from_name = "Zulip"/from_name = settings.INSTALLATION_NAME/' "$F"; \
    grep -q 'from_name = settings.INSTALLATION_NAME' "$F"; \
    echo "remetente do correio: INSTALLATION_NAME"

# 2. Os catálogos de tradução.
#
# O texto dos emails passa quase todo por `{% trans %}`, e o nome do fabricante
# está DENTRO das frases traduzidas («a conta Zulip»). Trocar no template mudava
# o identificador da frase e deitava fora a tradução; troca-se do lado da
# tradução, e recompila-se. Só as línguas que usamos — mexer em sessenta
# catálogos que ninguém lê é risco sem retorno.
COPY marca/catalogos.py /tmp/catalogos.py

RUN set -eu; \
    python3 /tmp/catalogos.py /home/zulip/deployments/current/locale "${NOME}" \
      pt pt_PT pt_BR; \
    cd /home/zulip/deployments/current/locale; \
    for l in pt pt_PT pt_BR; do \
      [ -f "$l/LC_MESSAGES/django.po" ] || continue; \
      msgfmt -o "$l/LC_MESSAGES/django.mo" "$l/LC_MESSAGES/django.po"; \
    done; \
    rm -f /tmp/catalogos.py; \
    restante=$(grep -c "Zulip" pt_PT/LC_MESSAGES/django.po || true); \
    echo "catalogos recompilados (msgid intactos: $restante mencoes)"

# 3. Um espaço que falta na tradução portuguesa do upstream.
#
# «Pedido de reposição de palavra-passe para%(realm_name)s» — sem espaço antes
# do nome da organização. Sai assim no assunto de todos os emails de reposição
# de palavra-passe. É defeito do catálogo do Zulip, mas o catálogo é nosso a
# partir daqui.
RUN set -eu; \
    cd /home/zulip/deployments/current/locale/pt_PT/LC_MESSAGES; \
    if grep -q "palavra-passe para%(realm_name)s" django.po; then \
      sed -i "s/palavra-passe para%(realm_name)s/palavra-passe para %(realm_name)s/g" django.po; \
      msgfmt -o django.mo django.po; \
      echo "espaco reposto no assunto da reposicao de palavra-passe"; \
    else \
      echo "o upstream ja corrigiu o espaco em falta"; \
    fi

# 7. Os três restos da moldura do portico.
#
# O que sobrou depois dos títulos e das traduções, e que se vê:
#   - `og:site_name`, que é o nome que aparece na pré-visualização de um link
#     partilhado no WhatsApp, no Slack ou onde for;
#   - dois atributos do logótipo (`alt` e um `content` solto);
#   - o rodapé: a tradução já dizia «Stratechna Chat», mas a LIGAÇÃO continuava
#     a apontar para o zulip.com — pior do que estava, porque prometia o nosso
#     nome e levava a outro sítio. Passa a ser um literal sem tradução: é uma
#     linha de marca, e lê-se igual em qualquer língua.
#
# O Zulip é Apache 2.0 e não exige atribuição na interface. A declaração de que
# o Stratechna Chat é construído sobre o Zulip está na página /licencas do
# Orbit, que é onde se lê.
RUN set -eu; \
    cd /home/zulip/deployments/current/templates/zerver; \
    grep -q 'og:site_name" content="Zulip"' meta_tags.html \
      || { echo "ERRO: o og:site_name mudou de forma"; exit 1; }; \
    sed -i "s#og:site_name\" content=\"Zulip\"#og:site_name\" content=\"${NOME}\"#" meta_tags.html; \
    grep -q "content=\"Zulip\"" portico-header.html \
      || { echo "ERRO: o logotipo do portico mudou de forma"; exit 1; }; \
    sed -i "s#alt=\"{{ _('Zulip') }}\"#alt=\"${NOME}\"#; s#content=\"Zulip\"#content=\"${NOME}\"#" portico-header.html; \
    grep -q 'https://zulip.com">Zulip</a>{% endtrans %}' footer.html \
      || { echo "ERRO: o rodape do portico mudou de forma"; exit 1; }; \
    sed -i "s#{% trans %}Powered by <a href=\"https://zulip.com\">Zulip</a>{% endtrans %}#Powered by <a href=\"https://stratechna.com/orbit/\">${NOME}</a>#" footer.html; \
    sobra=$(grep -c "Zulip" meta_tags.html portico-header.html | grep -v ":0" | wc -l); \
    echo "moldura do portico tratada (ficheiros com restos: $sobra)"

# 8. O que não faz sentido num Chat nosso, e o favicon.
#
# «Desktop & mobile apps» leva o cliente a descarregar o cliente de desktop do
# fabricante, com a marca dele. Não é o comutador de apps do Orbit — esse vive
# na grelha; isto é literalmente a loja de aplicações do Zulip. Esconde-se por
# folha de estilo própria, referenciada no `base.html`: mexer no `<li>` dentro
# do pacote compilado seria alterar um template de handlebars minificado, que é
# a coisa mais frágil que há aqui.
#
# E o favicon, que tinha ficado a ser o do fabricante — é o que se vê no
# separador do browser e nos favoritos.
# NÃO se usa o `static()` do Django aqui. O Zulip serve os estáticos com
# `ManifestStaticFilesStorage`, que exige que o ficheiro conste de um manifesto
# gerado na construção do upstream; um ficheiro nosso não consta, e o
# `static('orbit-marca.css')` rebenta com «Missing staticfiles manifest entry»
# em TODAS as páginas — o que deitou o Chat abaixo com 500 a 25-09-2026.
# Caminho literal, com versão à mão para a cache.
COPY marca/orbit.css /home/zulip/prod-static/orbit-marca.css
COPY marca/ficheiros/chat-icone.png /home/zulip/prod-static/images/favicon.png
COPY marca/ficheiros/chat-icone.svg /home/zulip/prod-static/images/favicon.svg

RUN set -eu; \
    F=/home/zulip/deployments/current/templates/zerver/base.html; \
    grep -q "orbit-marca.css" "$F" && { echo "ja referenciada"; exit 0; }; \
    grep -q "{% block webpack %}" "$F" || { echo "ERRO: o base.html mudou de forma"; exit 1; }; \
    sed -i "s#{% block webpack %}#<link rel=\"stylesheet\" href=\"/static/orbit-marca.css?v=1\" />\n        {% block webpack %}#" "$F"; \
    grep -q "orbit-marca.css" "$F" || { echo "ERRO: a folha de estilo nao ficou referenciada"; exit 1; }; \
    echo "folha de estilo da marca referenciada no base.html"

USER root
