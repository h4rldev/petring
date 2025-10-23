# Single stage using Alpine
FROM rust:slim-trixie AS builder

# Install SQLite and just from Alpine repository
RUN apt-get update && apt-get install -y \
    just \
    libssl-dev \
    pkg-config \
    gcc \
		sqlite3

# Set up workspace
WORKDIR /app

COPY migration ./migration/
COPY src ./src/
COPY templates ./templates/
COPY Cargo.toml .
COPY justfile .

RUN just build

FROM debian:trixie-slim

WORKDIR /app

COPY frontend ./frontend/
COPY --from=builder /app/target/release/petring ./petring

ENTRYPOINT ["./petring"]
