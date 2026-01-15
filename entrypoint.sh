#!/bin/bash
set -euo pipefail

export DISPLAY=:99
export NO_AT_BRIDGE=1
export SESSION_MANAGER=""

APP_USER=user
APP_UID=1000
APP_GID=1000

export XDG_RUNTIME_DIR="/run/user/${APP_UID}"
mkdir -p "${XDG_RUNTIME_DIR}"
chown "${APP_UID}:${APP_GID}" "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

echo "Starting Tailscale daemon..."
nohup tailscaled >/dev/null 2>&1 &
echo

echo "Starting TigerVNC server on DISPLAY=$DISPLAY..."
Xvnc -alwaysshared ${DISPLAY} -geometry 1920x1080 -depth 24 -rfbport 5900 -SecurityTypes None &
sleep 2
echo "TigerVNC server running on DISPLAY=$DISPLAY"
echo

echo "Starting DBus session (as ${APP_USER})..."
export XDG_RUNTIME_DIR="/run/user/${APP_UID}"
mkdir -p "${XDG_RUNTIME_DIR}"
chown "${APP_UID}:${APP_GID}" "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"
DBUS_SOCK="${XDG_RUNTIME_DIR}/bus"
rm -f "${DBUS_SOCK}"
su - "${APP_USER}" -c "XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR}' dbus-daemon --session --address='unix:path=${DBUS_SOCK}' --fork"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${DBUS_SOCK}"
echo "DBus started at ${DBUS_SESSION_BUS_ADDRESS}"
echo


echo "Configuring hosts file for ad blocking..."
wc -l /app/hosts
cat /app/hosts >> /etc/hosts
echo

echo "Starting tinyproxy on port 8119..."
tinyproxy -d -c /app/tinyproxy.conf &
for i in {1..5}; do
  sleep 2
  if curl -x http://127.0.0.1:8119 ip.fly.dev; then
    echo "Tinyproxy is up and running"
    break
  fi
  echo "Proxy check: attempt $i failed, retrying in 2 seconds..."
done
echo

echo "Starting XFCE4..."
su - "${APP_USER}" -c "DISPLAY=${DISPLAY} XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR} DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS} startxfce4 >/dev/null 2>&1 &"
sleep 3

su - "${APP_USER}" -c "DISPLAY=${DISPLAY} xeyes &"

echo "Starting Chromium..."
su - "${APP_USER}" -c "DISPLAY=${DISPLAY} \
  chromium --start-maximized --no-sandbox --remote-debugging-port=9221 \
  --disable-dev-shm-usage --proxy-server='http://127.0.0.1:8119' duck.com &"

socat TCP-LISTEN:9222,fork,reuseaddr TCP:127.0.0.1:9221 &

echo "Starting noVNC on port 80 (root)..."
websockify --web /usr/share/novnc/ 80 localhost:5900 &

echo "VNC server started on port 5900"
echo "noVNC viewable at http://localhost:80"

# Keep the container running 
while true; do sleep 1; done