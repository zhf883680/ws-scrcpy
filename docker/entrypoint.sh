#!/bin/sh
set -eu

if [ -z "${ADB_HOST:-}" ]; then
    adb start-server

    if [ -n "${ADB_DEVICE:-}" ]; then
        adb connect "${ADB_DEVICE}"
    fi
fi

exec "$@"
