FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    ring \
    libgtk-4-1 libwebkitgtk-6.0-4 \
    cmake ninja-build pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Ring packages
RUN ringpm install webview from ysdragon
RUN ringpm install ring-libsql from ysdragon

WORKDIR /app
COPY . /app

# Build frontend if present
RUN cd frontend && npm install && npm run build

EXPOSE 8080
CMD ["ring", "app.ring"]
