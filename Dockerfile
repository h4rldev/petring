# Single stage using Alpine
FROM rust:slim-trixie AS builder

USER root

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
COPY frontend ./frontend/
COPY src ./src/
COPY templates ./templates/
COPY Cargo.toml .
COPY justfile .

# Create empty SQLite database

ARG DB_NAME=petring.db
ARG DATABASE_URL=sqlite://${DB_NAME}

ENV DB_NAME=${DB_NAME}
ENV DATABASE_URL=${DATABASE_URL}

RUN touch petring.toml
RUN sqlite3 ${DB_NAME} "VACUUM;"

RUN just migrations ${DB_NAME} up
RUN just build

FROM debian:trixie-slim

ARG DB_NAME=petring.db
ENV DB_NAME=${DB_NAME}

RUN groupadd -r appgroup && useradd -r -g appgroup -d /app appuser

# Copy files to /app
COPY --from=builder /app/${DB_NAME} /app/${DB_NAME}
COPY --from=builder /app/petring.toml /app/petring.toml
COPY --from=builder /app/target/release/petring /app/petring

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app/${DB_NAME}
RUN chown -R appuser:appgroup /app/petring.toml
RUN chown -R appuser:appgroup /app/petring

# Set proper permissions
RUN chmod 644 /app/petring.toml
RUN chmod 644 /app/${DB_NAME}
RUN chmod +x /app/petring

# Switch to non-root user
USER appuser

WORKDIR /app

ENTRYPOINT ["./petring"]
