# sshfs-client

## 主な用途

* 継続的デプロイ（Continuous deployment; CD）で SFTP 接続可能な外部ホスティングサーバーのディレクトリをリモートマウントしてファイルを配置する。
* rsync コマンドを使用して内容差分があるファイルだけを転送する。
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
deploy-job:
    stage: deploy
    tags:
        - docker
    image: k1tajima/sshfs-client
    variables:
        SRC: deploy/files/path
        DEST: remote-user@remote-host.example.com:/remote/host/path
        ## known_hosts を無効化
        SSHFS_OPTS: -o allow_other,reconnect,UserKnownHostsFile=/dev/null,StrictHostKeyChecking=no
    script:
        - echo Deploy $SRC to $DEST
        ## GitLab-CI Variables: SSH_KEY as File Type Variable
        ## See https://docs.gitlab.com/ee/ci/variables/#file-type
        - chmod 700 $SSH_KEY
        - sshfs -o IdentityFile=$SSH_KEY $SSHFS_OPTS $DEST /mnt/remote
        ## ミラーリング（チェックサムによる更新判定・削除反映）
        - rsync -rlvh --checksum --delete $SRC/ /mnt/remote
        - ls -alR /mnt/remote > remote_ls-alR.txt
        - umount /mnt/remote
    artifacts:
        paths:
            - remote_ls-alR.txt
```

* GitLab-Runner として Docker 上で実行されるものを使用するように tags: を指定する。

  なお、その GitLab-Runner の設定で Docker イメージ実行オプションに privileged = true が追加されている必要がある（/dev/fuse を利用するため）。

    > https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-runnersdocker-section

* SSH 接続に使用する秘密鍵は、[環境変数][file-type-variables] `SSH_KEY` に秘密鍵の内容を設定する。
* sshfs コマンドを使用してリモートディレクトリを /mnt/remote にマウントする。
* rsync コマンドでリモートディレクトリと同期する。`--checksum` オプションで差分があるファイルのみ転送する。
* rsync -a オプションでは所有者やグループの同期でエラーになる場合があるため、代わりに -rl オプションを使用する。

[file-type-variables]: https://docs.gitlab.com/ee/ci/variables/#file-type

### Docker 環境でインタラクティブに使用する例

```bash
docker run --rm -it \
    -v "$PWD/.ssh:/config/.ssh" \
    -v "$PWD/deploy/files/path:/mnt/local" \
    --cap-add SYS_ADMIN \
    --device /dev/fuse \
    k1tajima/sshfs-client

## コンテナ内のshellでマウントしてファイル操作
sshfs -o IdentityFile=/config/.ssh/id_rsa -o allow_other,reconnect remote-user@remote-host.example.com:/remote/host/path /mnt/remote
rsync -rlcvh --delete /mnt/local/ /mnt/remote
ls -alR /mnt/remote > remote_ls-alR.txt
umount /mnt/remote
```

* SSH 接続に使用する秘密鍵や known_hosts ファイルなどの格納先 .ssh ディレクトリを /config/.ssh ボリュームにマウントする。
* 同期させるローカルディレクトリを /mnt/local ボリュームにマウントする。
* sshfs コマンドを使用してリモートディレクトリを /mnt/remote にマウントする。
* rsync コマンドでリモートディレクトリと同期する。

## 関連情報

* [sshfs - GitHub libfuse/sshfs](https://github.com/libfuse/sshfs)
* [pschmitt/sshfs - Docker Hub](https://hub.docker.com/r/pschmitt/sshfs)

以上
