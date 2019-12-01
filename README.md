# sshfs-client

## 主な用途

* 継続的デプロイ（Continuous deployment; CD）で SFTP 接続可能な外部ホスティングサーバーのディレクトリをリモートマウントしてファイルを配置する。
* 自動マウントには未対応のため、コンテナ内で sshfs コマンドを使用してリモートマウントする。

## 他の方法との比較

* [rsync][rsync] コマンドが使用可能であれば --delete オプションを付けることでミラーリングできるが、ssh コマンドによるログインやリモート操作が許可されていないサーバーでは rsync コマンドによるリモート操作ができない。

  > 例：Zenlogic では `"exec request failed on channel 0"` となり、失敗する。

* [sftp][sftp] コマンドを使用する場合、削除の同期もできるミラーリング機能がなく、既存ファイルを一掃するのも手間が掛かる（[lftp][lftp] コマンドならミラーリングにも対応）。
* [sshfs][sshfs] コマンドでディレクトリをリモートマウントすれば、rsync -a --delete コマンドでミラーリングできるし、rm -rf コマンドでファイル一掃など、様々なファイル操作ができる。

[rsync]: https://linux.die.net/man/1/rsync
[sftp]: https://linux.die.net/man/1/sftp
[lftp]: https://linux.die.net/man/1/lftp
[sshfs]: https://linux.die.net/man/1/sshfs

## 使い方

### GitLab-CICD で自動デプロイに使用する例

**.gitlab-ci.yml**

```yml
stages:
    - deploy

image: k1tajima/sshfs-client:latest

deploy-job:
    stage: deploy
    tags:
        - docker
    variables:
        SRC: deploy/files/path
        DEST: remote-user@remote-host.example.com:/remote/host/path
        SSH_KEY_FILE: id_rsa
        SSHFS_OPTS: -o allow_other,reconnect
    script:
        - if [ -z $SSH_KEY ]; then echo "$SSH_KEY" > /config/.ssh/$SSH_KEY_FILE; fi
        - cp .ssh/* /config/.ssh/ && chmod -R 700 /config/.ssh
        - sshfs -o IdentityFile=/config/.ssh/$SSH_KEY_FILE $SSHFS_OPTS $DEST /mnt/remote
        ## Sync to mirroring
        - rsync -avhz --delete $SRC/ /mnt/remote
        ## Clean and Copy all
        # - rm -rf /mnt/remote/*
        # - cp -rT $SRC /mnt/remote
        - ls -al /mnt/remote
        ## Unmount on Alpine Linux
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
    -v "$PWD/.ssh:/config/.ssh" -v "$PWD:/mnt/local" \
    --cap-add SYS_ADMIN --device /dev/fuse \
    k1tajima/sshfs-client

# コンテナ内のshellでマウントしてファイル操作
sshfs -o IdentityFile=/config/.ssh/id_rsa remote-user@remote-host.example.com:/remote/host/path /mnt/remote
rm -rf /mnt/remote/*
cp -rT /mnt/local/deploy/files/path /mnt/remote
ls -al /mnt/remote
umount /mnt/remote
```

* コンテナ実行時に SSH 接続に使用する秘密鍵や known_hosts ファイルなどの格納先 .ssh ディレクトリを /config/.ssh ボリュームにマウントする。
* インストール済みの sshfs コマンドを使用してリモートディレクトリを /mnt/remote にマウントする。
* リモートディレクトリ内のファイルを一掃して、手元のファイル一式をコピーする。

## 関連情報

* [sshfs - GitHub libfuse/sshfs](https://github.com/libfuse/sshfs)
* [pschmitt/sshfs - Docker Hub](https://hub.docker.com/r/pschmitt/sshfs)

以上
