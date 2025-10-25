default:
    just --list

@run binary="petring-web" +args="":
    cargo run --release --bin {{ binary }} -- {{ args }}

@run-dev +args="":
    cargo run -- {{ args }}

@build:
    cargo build --release

@build-dev:
    cargo build

@migrations +args="":
    just --justfile api/migration/justfile migrations {{ args }}
