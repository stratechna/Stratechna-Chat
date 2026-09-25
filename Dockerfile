# Stratechna Chat — camada de marca por cima do Zulip.
#
# Porque é que esta camada existe, quando a regra era não a haver
# ---------------------------------------------------------------
# A 16-09-2026 decidiu-se NÃO fazer camada de imagem no Zulip: o nome do
# fabricante, na interface web, está dentro de pacotes de webpack com hash de
# conteúdo, e uma camada de substituição de texto aí parte-se em silêncio a cada
# actualização. Essa decisão mantém-se para a interface.
#
# O CORREIO é outra coisa. A identidade dos emails que o servidor envia vive em
# três sítios estáveis — uma linha de Python, a moldura dos templates, e os
# catálogos de tradução — e era o que os clientes estavam a receber: mensagens
# assinadas «Zulip», com o logótipo do Zulip. A marca por organização (ícone,
# logótipos, nome, descrição) não chega lá: é da interface, não do correio.
#
# Regra da casa: cada substituição verifica o seu padrão antes, e a construção
# falha se o padrão tiver desaparecido. Uma marca que some numa actualização sem
# ninguém dar por isso é pior do que uma construção vermelha.
ARG ZULIP_VERSION=11.2-0
FROM zulip/docker-zulip:${ZULIP_VERSION}

ARG NOME="Stratechna Chat"
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

# 2. A moldura dos emails.
RUN set -eu; \
    cd /home/zulip/deployments/current/templates/zerver/emails; \
    n=0; \
    for f in email_base_default.html email_base_marketing.html email_base_messages.html; do \
      [ -f "$f" ] || continue; \
      grep -q '<title>Zulip</title>' "$f" || continue; \
      sed -i "s|<title>Zulip</title>|<title>${NOME}</title>|" "$f"; \
      n=$((n + 1)); \
    done; \
    [ "$n" -ge 1 ] || { echo "ERRO: nenhuma moldura de email tinha o titulo do fabricante"; exit 1; }; \
    echo "molduras de email tratadas: $n"

# 3. Os catálogos de tradução.
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

# 4. Um espaço que falta na tradução portuguesa do upstream.
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

USER root
