# server-setup

curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/duchoang/server-setup/master/init-setup.sh | SWAP_SIZE=8 sh

curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/duchoang/server-setup/master/gitlab-runner-setup.sh | SWAP_SIZE=4 GITLAB=https://gitlab.example.com/ TOKEN=yyy sh

