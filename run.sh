#! /bin/bash

docker run -d -it \
	-p 3400:8443 \
	--restart always \
	--name my-vscode \
	-v "/var/www:/home/coder/projects" \
	-v "/home/roman:/home/coder/workspaces" \
	myvs_full2 \
	--allow-http \
	--no-auth
