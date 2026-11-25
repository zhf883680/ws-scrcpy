# Docker image

The `Build and publish GHCR image` workflow builds the image on GitHub Actions
and publishes it to:

```text
ghcr.io/zhf883680/ws-scrcpy:latest
```

Images are built for `linux/amd64` and `linux/arm64`.

## USB-connected Android device

USB passthrough requires a Linux Docker host:

```sh
docker compose pull
docker compose up -d
docker exec ws-scrcpy adb devices
```

Approve the USB debugging prompt on the Android device when it appears. The
ADB authorization keys are stored in the `adb-keys` volume.

## Network ADB

Remove the `devices` entry from `docker-compose.yml` when USB passthrough is not
available or when the Android device is connected over Wi-Fi.

For Android 11 and later, pair once and then connect:

```sh
docker exec -it ws-scrcpy adb pair 192.168.1.50:PAIRING_PORT
docker exec -it ws-scrcpy adb connect 192.168.1.50:CONNECTION_PORT
docker exec ws-scrcpy adb devices
```

Set `ADB_DEVICE=192.168.1.50:CONNECTION_PORT` in the environment to reconnect
automatically when the container starts.

To use an existing ADB server instead, set both `ADB_HOST` and optionally
`ADB_PORT` on the container. The ADB server must be reachable from the
container.

## Security

ws-scrcpy has no built-in authentication. Publish port `8000` only on a trusted
LAN or WireGuard interface. Do not expose the web UI or ADB server directly to
the public internet.
