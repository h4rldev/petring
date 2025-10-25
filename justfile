set quiet := true

default:
    just --list

@run binary="petring-web" +args="":
    cargo run --release --bin {{ binary }} -- {{ args }}

@run-dev +args="":
    cargo run -- {{ args }}

build binary="both":
    #!/usr/bin/env bash
    if [ "{{ binary }}" == "both" ]; then
    		just build petring-api
    		just build petring-web
    else
    		echo "Building {{ binary }}"
    		cargo build --release --bin {{ binary }}
    fi

@build-dev:
    cargo build

@migrations +args="":
    just --justfile api/migration/justfile migrations {{ args }}
