#! /bin/bash

docker run -it -p 5000:8443 --name my-vscode \
    -v "/var/www:/home/coder/projects" \
    myvs_full \
    --allow-http \
    --no-auth
