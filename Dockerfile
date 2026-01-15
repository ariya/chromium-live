FROM mirror.gcr.io/library/debian:13-slim


RUN apt-get update -y && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates \
    tinyproxy \
    xterm \
    tigervnc-standalone-server \
    xfonts-base \
    xfonts-75dpi \
    xfonts-100dpi \
    xfce4 \
    xfce4-goodies \
    xfconf \
    tar \
    gtk2-engines-murrine \
    dbus-x11 \
    novnc \
    websockify \
    x11-apps \
    sudo \
    socat \
    screen \
    chromium


RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list >/dev/null
RUN apt-get update -y && apt-get install -y tailscale

WORKDIR /app
RUN curl -L https://github.com/B00merang-Project/Windows-10/archive/refs/heads/master.tar.gz -o /app/Theme.tar.gz

COPY entrypoint.sh /app/entrypoint.sh
COPY tinyproxy.conf /app/tinyproxy.conf
RUN chmod +x /app/entrypoint.sh

RUN cp /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html
RUN sed -i 's/rfb.scaleViewport = readQueryVariable.*$/rfb.scaleViewport = true;/' /usr/share/novnc/index.html

RUN curl -o /tmp/hblock 'https://raw.githubusercontent.com/hectorm/hblock/v3.5.1/hblock' \
  && echo 'd010cb9e0f3c644e9df3bfb387f42f7dbbffbbd481fb50c32683bbe71f994451  /tmp/hblock' | shasum -c \
  && mv /tmp/hblock /usr/local/bin/hblock \
  && chown 0:0 /usr/local/bin/hblock \
  && chmod 755 /usr/local/bin/hblock \
  && /usr/local/bin/hblock --output /app/hosts --header none

RUN useradd -m -u 1000 -s /bin/bash user && \
    chown -R user:user /app

RUN echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user && \
    chmod 0440 /etc/sudoers.d/user

EXPOSE 5900
EXPOSE 80
EXPOSE 9222

ENTRYPOINT ["/app/entrypoint.sh"]
