# server-setup

curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/duchoang/server-setup/master/init-setup.sh | SWAP_SIZE=8 sh

curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/duchoang/server-setup/master/gitlab-runner-setup.sh | SWAP_SIZE=4 \
GITLAB=https://git.url.com/ \
TOKEN=yyy \
sh 

curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/duchoang/server-setup/master/gitlab-server-setup.sh | SWAP_SIZE=4 \
CLOUDFARE=true \
REG_EXT_URL=https://registry.url.com \
EXT_URL=https://git.url.com \
GITLAB_APP_ID=app_id \
GITLAB_APP_SECRET=secret \
sh && gitlab-ctl reconfigure && gitlab-ctl restart
