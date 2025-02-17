# syntax=docker/dockerfile:1

FROM ghcr.io/imagegenius/baseimage-ubuntu:lunar

# set version label
ARG BUILD_DATE
ARG VERSION
ARG IMMICH_VERSION
LABEL build_version="ImageGenius Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz, martabal"

# environment settings
ENV TRANSFORMERS_CACHE="/config/machine-learning" \
  TYPESENSE_DATA_DIR="/config/typesense" \
  TYPESENSE_VERSION="0.24.1" \
  TYPESENSE_API_KEY="xyz" \
  TYPESENSE_HOST="127.0.0.1" \
  PUBLIC_IMMICH_SERVER_URL="http://127.0.0.1:3001" \
  IMMICH_MACHINE_LEARNING_URL="http://127.0.0.1:3003" \
  IMMICH_MEDIA_LOCATION="/photos" \
  MACHINE_LEARNING_CACHE_FOLDER="/config/machine-learning"

RUN \
  echo "**** install runtime packages ****" && \
  echo 'deb [arch=amd64] https://repo.jellyfin.org/ubuntu lunar main' > /etc/apt/sources.list.d/jellyfin.list && \
  curl -s https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/jellyfin_team.gpg >/dev/null && \
  echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x lunar main" >>/etc/apt/sources.list.d/node.list && \
  curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg >/dev/null && \
  apt-get update && \
  libvips_dev_dependencies=$(apt-cache depends libvips-dev | awk '/Depends:/{print $2}' | grep -Ev '[<>]|libmagickwand-dev|libmagickcore-dev|libvips42|gir1.2-vips-8.0|libtiff-dev') && \
  libvips_dependencies=$(apt-cache depends libvips42 | awk '/Depends:/{print $2}' | grep -Ev '[<>]|libmagickcore-6.q16-6|libtiff6') && \
  apt-get install --no-install-recommends -y \
    $libvips_dev_dependencies \
    bc \
    build-essential \
    jellyfin-ffmpeg6 \
    g++ \
    intel-media-va-driver-non-free \
    libexif-dev \
    libltdl-dev \
    libmimalloc2.0 \
    libtool \
    make \
    mesa-va-drivers \
    meson \
    nginx \
    ninja-build \
    nodejs \
    perl \
    python3-dev \
    python3-pip \
    python3-venv && \
  ln -s /usr/lib/jellyfin-ffmpeg/ffmpeg /usr/bin && \
  ln -s /usr/lib/jellyfin-ffmpeg/ffprobe /usr/bin && \
  echo "**** download immich ****" && \
  mkdir -p \
    /tmp/immich && \
  if [ -z ${IMMICH_VERSION} ]; then \
    IMMICH_VERSION=$(curl -sL https://api.github.com/repos/immich-app/immich/releases/latest | \
      jq -r '.tag_name'); \
  fi && \
  curl -o \
    /tmp/immich.tar.gz -L \
    "https://github.com/immich-app/immich/archive/${IMMICH_VERSION}.tar.gz" && \
  tar xf \
    /tmp/immich.tar.gz -C \
    /tmp/immich --strip-components=1 && \
  echo "**** download libraw ****" && \
  mkdir -p \
    /tmp/libraw && \
  if [ -z ${LIBRAW_VERSION} ]; then \
    LIBRAW_VERSION=$(jq -r '.packages[] | select(.name == "libraw") | .version' \
      /tmp/immich/server/build-lock.json); \
  fi && \
  curl -o \
    /tmp/libraw.tar.gz -L \
    "https://github.com/libraw/libraw/archive/${LIBRAW_VERSION}.tar.gz" && \
  cd /tmp && \
  tar xf \
    /tmp/libraw.tar.gz -C \
    /tmp/libraw --strip-components=1 && \
  echo "**** build libraw ****" && \
  cd /tmp/libraw && \
  autoreconf --install && \
  ./configure && \
  make -j4 && \
  make install && \
  ldconfig /usr/local/lib && \
  echo "**** download imagemagick ****" && \
  mkdir -p \
    /tmp/imagemagick && \
  if [ -z ${IMAGE_MAGICK_VERSION} ]; then \
    IMAGE_MAGICK_VERSION=$(jq -r '.packages[] | select(.name == "imagemagick") | .version' \
      /tmp/immich/server/build-lock.json); \
  fi && \
  curl -o \
    /tmp/imagemagick.tar.gz -L \
    "https://github.com/ImageMagick/ImageMagick/archive/${IMAGE_MAGICK_VERSION}.tar.gz" && \
  cd /tmp && \
  tar xf \
    /tmp/imagemagick.tar.gz -C \
    /tmp/imagemagick --strip-components=1 && \
  echo "**** build imagemagick ****" && \
  cd /tmp/imagemagick && \
  patch -u coders/dng.c -i /tmp/immich/server/bin/use-camera-wb.patch && \
  ./configure --with-modules && \
  make -j4 && \
  make install && \
  ldconfig /usr/local/lib && \
  echo "**** download libvips ****" && \
  mkdir -p \
    /tmp/libvips && \
  if [ -z ${IMAGE_LIBVIPS_VERSION} ]; then \
    IMAGE_LIBVIPS_VERSION=v$(jq -r '.packages[] | select(.name == "libvips") | .version' \
      /tmp/immich/server/build-lock.json); \
  fi && \
  curl -o \
    /tmp/libvips.tar.gz -L \
    "https://github.com/libvips/libvips/archive/${IMAGE_LIBVIPS_VERSION}.tar.gz" && \
  cd /tmp && \
  tar xf \
    /tmp/libvips.tar.gz -C \
    /tmp/libvips --strip-components=1 && \
  echo "**** build libvips ****" && \
  cd /tmp/libvips && \
  meson build --libdir=lib --buildtype=release -Dintrospection=false -Dtiff=disabled && \
  cd build && \
  meson compile && \
  meson test && \
  meson install && \
  ldconfig && \
  echo "**** download typesense ****" && \
  mkdir -p \
    /app/typesense && \
  curl -o  \
    /tmp/typesense.tar.gz -L \
    https://dl.typesense.org/releases/${TYPESENSE_VERSION}/typesense-server-${TYPESENSE_VERSION}-linux-amd64.tar.gz && \
  tar -xf \
    /tmp/typesense.tar.gz -C \
    /app/typesense && \
  echo "**** build server ****" && \
  cd /tmp/immich/server && \
  npm ci && \
  npm run build && \
  npm prune --omit=dev --omit=optional && \
  npm link && \
  npm cache clean --force && \
  mkdir -p \
    /app/immich/server && \
  cp -a \
    package.json \
    package-lock.json \
    node_modules \
    dist \
    /app/immich/server && \
  echo "**** build web ****" && \
  cd /tmp/immich/web && \
  npm ci && \
  npm run build && \
  npm prune --omit=dev && \
  mkdir -p \
    /app/immich/web && \
  cp -a \
    package.json \
    package-lock.json \
    node_modules \
    build \
    static \
    /app/immich/web && \
  echo "**** build machine-learning ****" && \
  cd /tmp/immich/machine-learning && \
  pip install --break-system-packages -U --no-cache-dir poetry && \
  python3 -m venv /lsiopy && \
  poetry config installer.max-workers 10 && \
  poetry config virtualenvs.create false && \
  poetry install --sync --no-interaction --no-ansi --no-root --only main && \
  poetry run pip install --no-deps -r requirements.txt && \
  mkdir -p \
    /app/immich/machine-learning && \
  cp -a \
    app \
    log_conf.json \
    /app/immich/machine-learning && \
  echo "**** install immich cli (immich upload) ****" && \
    npm install -g --prefix /tmp/cli immich && \
    mv /tmp/cli/lib/node_modules/immich /app/cli && \
  echo "**** cleanup ****" && \
  for cleanfiles in *.pyc *.pyo; do \
    find /usr/local/lib/python3.* /usr/lib/python3.* /lsiopy/lib/python3.* -name "${cleanfiles}" -delete; \
  done && \
  apt-get remove -y --purge \
    $libvips_dev_dependencies \
    bc \
    build-essential \
    g++ \
    libexif-dev \
    libltdl-dev \
    libtool \
    make \
    meson \
    ninja-build \
    python3-dev && \
  apt-get install --no-install-recommends -y \
    $libvips_dependencies \
    libexif12 \
    libltdl7 && \
  apt-get autoremove -y --purge && \
  apt-get clean && \
  rm -rf \
    /tmp/* \
    /var/tmp/* \
    /var/lib/apt/lists/* \
    /root/.cache \
    /root/.npm \
    /etc/apt/sources.list.d/node.list \
    /etc/apt/sources.list.d/jellyfin.list \
    /usr/share/keyrings/nodesource.gpg \
    /etc/apt/trusted.gpg.d/jellyfin_team.gpg

# copy local files
COPY root/ /

# environment settings
ENV NODE_ENV="production"

# ports and volumes
EXPOSE 8080
VOLUME /config /uploads
