# ==============================================================================
# Mejde Network - Mother Node Container (Powered by Ring Language)
# Reference: https://github.com/ysdragon/deploy-ring
# ==============================================================================

FROM ubuntu:22.04 AS builder

# Prevent interactive timezone prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies for Ring and extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    libssl-dev \
    libcurl4-openssl-dev \
    sqlite3 \
    libsqlite3-dev \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Clone and build official Ring Language compiler & runtime
WORKDIR /build
RUN git clone --depth 1 https://github.com/ring-lang/ring.git
WORKDIR /build/ring/src
RUN make -f MakefileDockerX64
RUN make -f MakefileDockerX64 install

# Build Ring Extensions (Sockets, OpenSSL, LibCurl, SQLite)
WORKDIR /build/ring/extensions/ringsockets
RUN gcc -c -fpic ringsockets.c -I /build/ring/language/include
RUN gcc -shared -o libring_sockets.so ringsockets.o
RUN cp libring_sockets.so /usr/lib/

WORKDIR /build/ring/extensions/ringopenssl
RUN gcc -c -fpic ring_openssl.c -I /build/ring/language/include
RUN gcc -shared -o libring_openssl.so ring_openssl.o -lssl -lcrypto
RUN cp libring_openssl.so /usr/lib/

WORKDIR /build/ring/extensions/ringlibcurl
RUN gcc -c -fpic ring_libcurl.c -I /build/ring/language/include
RUN gcc -shared -o libring_libcurl.so ring_libcurl.o -lcurl
RUN cp libring_libcurl.so /usr/lib/

WORKDIR /build/ring/extensions/ringsqlite
RUN gcc -c -fpic ringsqlite.c -I /build/ring/language/include
RUN gcc -shared -o libring_sqlite.so ringsqlite.o -lsqlite3
RUN cp libring_sqlite.so /usr/lib/

# ==============================================================================
# Runtime Stage (Minimal production image)
# ==============================================================================
FROM ubuntu:22.04 AS runner

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    libcurl4 \
    libsqlite3-0 \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy installed Ring binaries, libs and standard libraries from builder
COPY --from=builder /usr/bin/ring /usr/bin/ring
COPY --from=builder /usr/lib/libring* /usr/lib/
COPY --from=builder /build/ring/bin/load /usr/lib/ring/load
COPY --from=builder /build/ring/language/src/buildvc/load /usr/lib/ring/load_alt
COPY --from=builder /build/ring/tools/ringpm /usr/lib/ringpm

# Create application directory and persistent data volume
WORKDIR /app
RUN mkdir -p /data /app/logs

# Copy Mejde node application files
COPY node.ring /app/
COPY libsql.ring /app/
COPY core/ /app/core/
COPY models/ /app/models/
COPY blockchain/ /app/blockchain/
COPY contracts/ /app/contracts/
COPY services/ /app/services/
COPY utils/ /app/utils/
COPY p2p/ /app/p2p/

# Expose P2P Gossip and Web Dashboard port
EXPOSE 8545

# Persistent database storage
VOLUME ["/data"]

# Environment defaults
ENV PORT=8545
ENV DB_FILE=/data/social_mother.db

# Health check using the live telemetry endpoint
HEALTHCHECK --interval=20s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8545/p2p/status || exit 1

# Run Headless Mother Node with Web Dashboard
CMD ["sh", "-c", "ring node.ring $PORT $DB_FILE"]
