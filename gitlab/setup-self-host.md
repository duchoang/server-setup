## Main compose for gitlab + registry

```bash
$ cat ~/gitlab/docker-compose.yml
```

```yml
version: '3.7'
services:
  web:
    image: 'gitlab/gitlab-ce:latest'
    restart: always
    hostname: 'gitlab.emvn.co'
    container_name: gitlab-ce
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://gitlab.emvn.co'
        nginx['redirect_http_to_https'] = true
        registry_external_url 'https://registry.emvn.co'
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - '/home/duc/gitlab/config:/etc/gitlab'
      - '/home/duc/gitlab/logs:/var/log/gitlab'
      - '/home/duc/gitlab/data:/var/opt/gitlab'
    networks:
      - gitlab

networks:
  gitlab:
    name: gitlab-network
```

## Runner setup in docker

```bash
$ cat ~/runner1/docker-compose.yml
```

```yml
version: "3.5"

services:
  dind:
    image: docker:20-dind
    restart: always
    privileged: true
    environment:
      DOCKER_TLS_CERTDIR: ""
    command:
      - --storage-driver=overlay2
    volumes:
      - ./data/dind/docker:/var/lib/docker
    networks:
      - gitlab

  runner:
    restart: always
    image: registry.gitlab.com/gitlab-org/gitlab-runner:alpine
    volumes:
      - ./config:/etc/gitlab-runner:z
      - ./data/runner/cache:/cache
        ###- /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DOCKER_HOST=tcp://dind:2375
    networks:
      - gitlab

  register-runner:
    restart: 'no'
    image: registry.gitlab.com/gitlab-org/gitlab-runner:alpine
    depends_on:
      - dind
    environment:
      - CI_SERVER_URL=${CI_SERVER_URL}
      - REGISTRATION_TOKEN=${REGISTRATION_TOKEN}
    command:
      - register
      - --non-interactive
      - --locked=false
      - --name=${RUNNER_NAME}
      - --executor=docker
      - --docker-image=docker:20-dind
      - --docker-volumes=/var/run/docker.sock:/var/run/docker.sock
    volumes:
      - ./config:/etc/gitlab-runner:z
      - ./data/dind/docker:/var/lib/docker
    networks:
      - gitlab

networks:
  gitlab:
    name: gitlab-network
    external: true
```

### Some reference
https://www.czerniga.it/2021/11/14/how-to-install-gitlab-using-docker-compose/
https://forum.gitlab.com/t/example-gitlab-runner-docker-compose-configuration/67344
https://gitlab.com/TyIsI/gitlab-runner-docker-compose/-/blob/main/docker-compose.yml
https://gist.github.com/boiyama/ad7405cd17d090a52b57728d9b0985cb
https://github.com/sameersbn/docker-gitlab/blob/master/docs/container_registry.md
