# sshfs-client

## 主な用途

* SSH 接続可能な外部ホスティングサーバーのディレクトリをリモートマウントしてファイルを配置する。
* SFTP を使用する場合はファイル一掃が難しいが、リモートマウントすれば rm -rf コマンドで簡単に一掃できる。

## docker image

* <http://docker-registry/containers/modern_dev/sshfs-client>

## 使い方

### GitLab-CICD で自動デプロイに使用する例

**.gitlab-ci.yml**

```yml
stages:
    - deploy

image: docker-registry:5000/modern_dev/sshfs-client:latest

deploy-job:
    stage: deploy
    tags:
        - docker
    variables:
        SRC: data/deploy/files/path
        DEST: remote-user@remote-host.example.com:/remote/host/path
        SSH_KEY_FILE: id_rsa
    script:
        - cp .ssh/* ~/.ssh/ && chmod -R 700 ~/.ssh
        - sshfs -o IdentityFile=~/.ssh/$SSH_KEY_FILE $DEST /mnt/remote
        - rm -rf /mnt/remote/*
        - cp -rT $SRC /mnt/remote
        - ls -al /mnt/remote
        - umount /mnt/remote
    artifacts:
        paths:
            - $SRC
```

* GitLab-Runner として Docker 上で実行されるものを使用するように tags: を指定する。

  なお、その GitLab-Runner の設定で Docker イメージ実行オプションに privileged = true が追加されている必要がある（/dev/fuse を利用するため）。

    > https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-runnersdocker-section

* SSH 接続に使用する秘密鍵や known_hosts ファイルなどをリポジトリの .ssh ディレクトリから /config/.ssh にコピーする。
* インストール済みの sshfs コマンドを使用してリモートディレクトリを /mnt/remote にマウントする。
* リモートディレクトリ内のファイルを一掃して、手元のファイル一式をコピーする。

### Docker 環境でインタラクティブに使用する例

```bash
docker run --rm -it \
    -v "$PWD/.ssh:/config/.ssh" -v "$PWD/data:/mnt/local" \
    --cap-add SYS_ADMIN --device /dev/fuse \
    docker-registry:5000/modern_dev/sshfs-client

# コンテナ内のshellでマウントしてファイル操作
sshfs -o IdentityFile=/config/.ssh/id_rsa remote-user@remote-host.example.com:/remote/host/path /mnt/remote
rm -rf /mnt/remote/*
cp -rT /mnt/local/deploy/files/path /mnt/remote
ls -al /mnt/remote
umount /mnt/remote
```

* SSH 接続に使用する秘密鍵の格納先 .ssh ディレクトリを /config/.ssh ボリュームにマウントする。
* インストール済みの sshfs コマンドを使用してリモートディレクトリを /mnt/remote にマウントする。
* リモートディレクトリ内のファイルを一掃して、手元のファイル一式をコピーする。

## 関連情報

* [sshfs - GitHub libfuse/sshfs](https://github.com/libfuse/sshfs)
* [pschmitt/sshfs - Docker Hub](https://hub.docker.com/r/pschmitt/sshfs)

以上
