FROM rust:slim-trixie AS chef
RUN cargo install cargo-chef
WORKDIR app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# Single stage using Alpine
FROM chef AS builder

# Install SQLite and just from Alpine repository
RUN apt-get update && apt-get install -y \
    just \
    libssl-dev \
    pkg-config \
    gcc \
		sqlite3

COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json

COPY migration ./migration/
COPY src ./src/
COPY templates ./templates/
COPY justfile .

RUN just build

FROM debian:trixie-slim AS runtime

WORKDIR /app

COPY frontend ./frontend/
COPY --from=builder /app/target/release/petring ./petring

ENTRYPOINT ["./petring"]
