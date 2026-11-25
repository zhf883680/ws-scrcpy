# ws-scrcpy 部署与运维记录

本文记录本 fork 的镜像构建、Docker 部署、无线 ADB 和 iPhone 播放器配置。
SSH 密码、ADB 配对码和一次性端口不会写入仓库。

## 镜像构建

GitHub Actions 工作流位于
`.github/workflows/publish-ghcr.yml`，在 `master` 分支发生镜像相关变更时构建：

- `linux/amd64`
- `linux/arm64`

镜像地址：

```text
ghcr.io/zhf883680/ws-scrcpy:latest
```

工作流会生成以下标签：

```text
latest
master
sha-<commit>
```

Dockerfile 使用 Debian 13 运行时，并在构建阶段验证 ADB 支持 `pair` 命令。
当前运行镜像包含 `adb 34.0.5`。

## 服务端部署

两台 Linux 主机均使用同一份 `docker-compose.yml`：

```text
/opt/ws-scrcpy/docker-compose.yml
```

本地仓库中的部署文件位于：

```text
docker-compose.yml
```

当前配置包括：

- Docker 重启策略：`unless-stopped`
- 容器网络：`host`
- Web UI：宿主机 `8000` 端口
- ADB mDNS 自动连接：`adb-tls-connect`
- USB 热插拔 cgroup 规则：`c 189:* rwm`
- `/dev/bus/usb` 直通
- ADB 密钥卷：`ws-scrcpy_adb-keys`
- `no-new-privileges`

启动或更新：

```sh
cd /opt/ws-scrcpy
docker compose pull
docker compose up -d
```

检查：

```sh
docker compose ps
docker exec ws-scrcpy adb version
docker exec ws-scrcpy adb devices -l
curl -fsS http://127.0.0.1:8000/ | grep '<title>'
```

## Android 无线调试

适用于 Android 11 及以上版本。

1. 打开“设置 → 关于手机”，连续点击“版本号”7 次。
2. 打开“设置 → 系统 → 开发者选项 → 无线调试”。
3. 打开“使用无线调试”。
4. 点击“使用配对码配对设备”。
5. 记录配对窗口中的 `IP:端口` 和 6 位配对码。
6. 配对完成后，记录无线调试主页显示的另一个 `IP:端口`。

配对和连接：

```sh
docker exec ws-scrcpy adb pair PHONE_IP:PAIRING_PORT PAIRING_CODE
docker exec ws-scrcpy adb connect PHONE_IP:CONNECTION_PORT
docker exec ws-scrcpy adb devices -l
```

配对端口和连接端口通常不同。关闭配对窗口后，配对码立即失效。

如果手机重启、关闭过无线调试或切换过网络，连接端口可能变化，需要重新查看
无线调试主页并执行 `adb connect`。

## iPhone 播放器配置

iPhone Safari 不支持 MSE，因此使用 `Broadway.js`。

部分 Android 设备默认输出 H.264 High Profile，Broadway 和 TinyH264 可能显示
黑屏。应强制使用软件编码器和 Baseline Profile：

```text
Player: Broadway.js
Codec options: profile:int=1
Encoder: OMX.google.h264.encoder
Fit to screen: 关闭
Max width: 720
Max height: 1600
Bitrate: 4 MiB
Max FPS: 24
I-Frame interval: 5
```

`720×1600 / 4 MiB` 是清晰度与软件编码性能的平衡配置。设备和网络都足够快时
可以尝试：

```text
Max width: 900
Max height: 2000
Bitrate: 6 MiB
```

修改编码参数前必须关闭所有旧播放器。ws-scrcpy 会按显示 ID 复用已有视频流；
旧客户端不关闭时，新参数可能不会触发编码器重建。

## 常见问题

### 黑屏

按顺序检查：

1. `Broadway.js` 是否显示。
2. 是否已点击 `Open`。
3. 手机是否亮屏并解锁。
4. `Codec options` 是否为 `profile:int=1`。
5. `Encoder` 是否为 `OMX.google.h264.encoder`。
6. 是否关闭了所有旧播放器。
7. `adb devices -l` 是否仍为 `device`。

使用 MSE 播放器可作为桌面端对照。如果 MSE 有画面而 Broadway/TinyH264 黑屏，
通常是 H.264 Profile 不兼容。

### 设备列表残留旧端口

旧 scrcpy server 进程可能导致同一手机显示为多个设备。重新连接当前端口后，
可以结束手机上的残留 `app_process`，再重启服务：

```sh
docker exec ws-scrcpy adb -s PHONE_IP:CONNECTION_PORT shell ps -A
docker exec ws-scrcpy adb -s PHONE_IP:CONNECTION_PORT shell kill -9 PID
docker compose restart
docker exec ws-scrcpy adb connect PHONE_IP:CONNECTION_PORT
```

### 画面模糊

优先增加 `Max width`、`Max height` 和码率，不要只提高码率。默认的约
480 像素宽度会明显发糊。

## 网络与安全

- ws-scrcpy 没有内置身份认证。
- 不要把 `8000` 或 ADB 端口直接映射到公网。
- 建议只允许局域网或 WireGuard 地址访问。
- WireGuard 只负责加密传输，不替代应用层认证。
- 修改静态网络配置前应备份 `/etc/network/interfaces` 和 `/etc/resolv.conf`。
