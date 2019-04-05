# Just use the code-server docker binary
FROM codercom/code-server as coder-binary
# FROM my-codeserver as coder-binary

FROM ubuntu:18.10 as vscode-env
ARG DEBIAN_FRONTEND=noninteractive

# Install the actual VSCode to download configs and extensions
RUN apt-get update && \
	apt-get install -y curl apt-utils libnotify4 libnss3 gnupg libxkbfile1 libsecret-1-0 libgtk-3-0 libxss1 && \
	curl -o vscode-amd64.deb -L https://vscode-update.azurewebsites.net/latest/linux-deb-x64/stable && \
	dpkg -i vscode-amd64.deb || true && \
	apt-get install -y -f && \
	# VSCode missing deps
	apt-get install -y libx11-xcb1 libasound2 && \
	rm -f vscode-amd64.deb && \
	# CLI json parser
	apt-get install -y jq

COPY scripts /root/scripts
COPY sync.gist /root/sync.gist

# This gets user config from gist, parse it and install exts with VSCode
RUN code -v --user-data-dir /root/.config/Code && \
	cd /root/scripts && \
	sh get-config-from-gist.sh &&  \
	sh parse-extension-list.sh && \
	sh install-vscode-extensions.sh ../extensions.list


# The production image for code-server
FROM node:8-slim

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG TZ="Europe/Bratislava"
ARG LOCALE="en_US.UTF-8"

RUN apt-get update \
	&& apt-get install -y --no-install-recommends sudo git python locales apt-transport-https lftp openssl nano net-tools libsecret-1-dev jq \
	&& wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add - \
    && echo "deb https://packages.sury.org/php/ jessie main" | tee /etc/apt/sources.list.d/php.list \
	&& apt-get update \
    && apt-get install -y --no-install-recommends php7.2 php7.2-cli \
    && curl -s -o composer-setup.php https://getcomposer.org/installer \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm composer-setup.php \
	# ripgrep
	&& REPO="https://github.com/BurntSushi/ripgrep/releases/download/" \
	&& RG_LATEST=$(curl -sSL "https://api.github.com/repos/BurntSushi/ripgrep/releases/latest" | jq --raw-output .tag_name) \
	&& RELEASE="${RG_LATEST}/ripgrep-${RG_LATEST}-x86_64-unknown-linux-musl.tar.gz" \
	&& TMPDIR=$(mktemp -d) \
	&& cd $TMPDIR \
	&& wget -O - ${REPO}${RELEASE} | tar zxf - --strip-component=1 \
	&& ls -la $TMPDIR \
	&& ls -la $TMPDIR/complete \
	&& mv rg /usr/bin/ \
	&& mv complete/rg.bash /usr/share/bash-completion/completions/rg \
	# clean
	&& apt-get remove -y build-essential xz-utils jq \
	&& apt-get clean autoclean \
	&& apt-get autoremove --yes \
	&& rm -rf /var/lib/{apt,dpkg,cache,log}/

RUN userdel -r -f node \
	&& groupadd -g ${GROUP_ID} coder \
	&& adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID coder \
	&& adduser coder sudo \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
	&& mkdir -p /home/coder/projects \
	&& mkdir -p /home/coder/workspaces \
	&& mkdir -p /home/coder/.local/share/code-server \
	&& mkdir -p /home/coder/.config/Code/ \
	&& mkdir -p /home/coder/.cache/code-server/logs \
	&& ln -s /home/coder/.local/share/code-server/User /home/coder/.config/Code/User \
	&& chown -R coder:coder /home/coder \
	&& touch /product.json \
	&& chown -R coder:coder /product.json \
	# timezone
	&& rm -f /etc/localtime \
    && ln -s /usr/share/zoneinfo/$TZ /etc/localtime \
    && sed -i 's/^# *\('$LOCALE'\)/\1/' /etc/locale.gen \
	# locale
    && locale-gen \
    && echo "export LC_ALL="$LOCALE >> /home/coder/.bashrc \
    && echo "export LANG="$LOCALE >> /home/coder/.bashrc \
    && echo "export LANGUAGE="$LOCALE >> /home/coder/.bashrc \
    && npm install gulp -g

WORKDIR /home/coder/project

COPY --from=coder-binary --chown=coder:coder /usr/local/bin/code-server /usr/local/bin/code-server
COPY --from=vscode-env --chown=coder:coder /root/settings.json /home/coder/.local/share/code-server/User/settings.json
COPY --from=vscode-env --chown=coder:coder /root/.vscode/extensions /home/coder/.local/share/code-server/extensions

USER coder

EXPOSE 8443
ENTRYPOINT ["code-server"]
