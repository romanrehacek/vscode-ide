#! /bin/bash

docker run -d -it \
	-p 3400:8443 \
	--restart always \
	--name my-vscode \
	-v "/var/www:/home/coder/projects" \
	-v "${HOME}:/home/coder/hosthome" \
	myvs_full \
	--allow-http \
	--no-auth
