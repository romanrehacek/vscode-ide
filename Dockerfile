# Just use the code-server docker binary
#FROM codercom/code-server as coder-binary
FROM my-codeserver as coder-binary

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
	sh get-config-from-gist.sh && \
	sh parse-extension-list.sh && \
	sh install-vscode-extensions.sh ../extensions.list


# The production image for code-server
FROM ubuntu:18.10

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG LOCALE=sk_SK

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates gnupg2 locales git curl wget \
	&& apt-get install -y --no-install-recommends build-essential xz-utils openssl net-tools \
	&& apt-get install -y --no-install-recommends sudo ripgrep nano \
	# Install Node.js
	&& curl -sL https://deb.nodesource.com/setup_11.x  | bash - \
	# Install Yarn
	&& curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
	&& echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
	&& apt-get update && apt-get install -y --no-install-recommends yarn nodejs \
	# Locale
	&& locale-gen ${LOCALE}.UTF-8 \
	# clean
	&& apt-get remove -y build-essential xz-utils \
	&& apt-get clean autoclean \
	&& apt-get autoremove --yes \
	&& rm -rf /var/lib/{apt,dpkg,cache,log}/

RUN groupadd -g ${GROUP_ID} coder \
	&& adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID coder \
	&& adduser coder sudo \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
	&& mkdir -p /home/coder/projects \
	&& mkdir -p /home/coder/workspaces \
	&& mkdir -p /home/coder/.local/share/code-server \
	&& mkdir -p /home/coder/.config/Code/ \
	&& ln -s /home/coder/.local/share/code-server/User /home/coder/.config/Code/User \
	&& chown -R coder:coder /home/coder \
	&& touch /product.json \
	&& chown -R coder:coder /product.json

WORKDIR /home/coder/project

COPY --from=coder-binary /usr/local/bin/code-server /usr/local/bin/code-server
COPY --from=vscode-env /root/settings.json /home/coder/.local/share/code-server/User/settings.json
COPY --from=vscode-env /root/.vscode/extensions /home/coder/.local/share/code-server/extensions

RUN chown -R coder:coder /home/coder/

# Locale Generation
# We unfortunately cannot use update-locale because docker will not use the env variables
# configured in /etc/default/locale so we need to set it manually.
ENV LANG=en_US.UTF-8
ENV LC_ALL=${LOCALE}.UTF-8

USER coder

EXPOSE 8443
ENTRYPOINT ["code-server"]
