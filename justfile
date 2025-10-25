default:
    just --list

@run +args="":
    cargo run --release -- {{args}}

@run-dev +args="":
    cargo run -- {{args}}

@build:
    cargo build --release

@build-dev:
    cargo build

@migrations +args="":
    just --justfile migration/justfile migrations {{args}}
