# syntax=docker/dockerfile:1

# ---- build ----
FROM rust:1-bookworm AS builder
WORKDIR /build
COPY Cargo.toml Cargo.lock ./
COPY entity ./entity
COPY server ./server
RUN cargo build --release -p server

# ---- runtime ----
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /build/target/release/server /usr/local/bin/server
COPY config.toml ./config.toml
EXPOSE 8080
CMD ["server"]
