default:
    just --list

@run binary="webserver" +args="":
    cargo run --release --bin {{binary}} -- {{args}}

@run-dev +args="":
    cargo run -- {{args}}

@build:
    cargo build --release

@build-dev:
    cargo build

@migrations +args="":
    just --justfile api/migration/justfile migrations {{args}}

@prepare-migrations:
		just --justfile api/migration/justfile prepare-bin

@cook-migrations:
		just --justfile api/migration/justfile cook-bin
