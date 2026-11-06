# Cross-build environment for OpenJK (Jedi Outcast SP) on goodluckOS (armhf).
FROM debian:bookworm
RUN dpkg --add-architecture armhf && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates git cmake make pkg-config zip file patchelf \
        crossbuild-essential-armhf \
        libsdl2-dev:armhf libopenal-dev:armhf libgl-dev:armhf \
        libjpeg62-turbo-dev:armhf libpng-dev:armhf zlib1g-dev:armhf && \
    rm -rf /var/lib/apt/lists/*
ENV PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig
ENV PKG_CONFIG_LIBDIR=/usr/lib/arm-linux-gnueabihf/pkgconfig
ENV PKG_CONFIG_ALLOW_CROSS=1
