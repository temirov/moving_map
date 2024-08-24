FROM ubuntu:20.04

RUN apt-get update && apt-get install -y \
    build-essential \
    libsqlite3-dev \
    zlib1g-dev \
    curl \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/mapbox/tippecanoe.git /tippecanoe

WORKDIR /tippecanoe

RUN make -j && make install

ENTRYPOINT ["tippecanoe"]
