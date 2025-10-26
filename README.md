# PetRing & PetAds

> [!WARNING]
> This project is in an early ALPHA and is not ready for any serious usecase
>
> Bugs will exist, and code will be messy; Keep that in mind.

This is a webring and navlink ad system for the Jess Museum Discord server.

## How to install

### Requirements

- Just (Optional)
- A stable Rust toolchain
  (preferrably stable-x86_64-unknown-linux-gnu, but musl can maybe work too)
- SQLite3
- OpenSSL (for generating random keys)

### Installation

- Make an empty directory, and enter it
- Run:

```bash
curl -fsSL https://raw.githubusercontent.com/h4rldev/petring/main/install.sh | bash
```

- Or run:

```bash
wget -O - https://raw.githubusercontent.com/h4rldev/petring/main/install.sh | bash
```

- Check out [Collar](https://github.com/h4rldev/collar) to actually use PetRing.

## How to build

### Prerequisites

- Just (Optional)
- A stable Rust toolchain
  (preferrably stable-x86_64-unknown-linux-gnu, but musl can maybe work too)
- SQLite3
- OpenSSL (for generating random keys)
- Docker (optional)

### Prebuild

- Initialize a sqlite database

```bash
sqlite3 petring.db "VACUUM;"
```

- Setup your `.env` file according to the `.env.example` file

- Then run the migrations

- With just:

```bash
just migrations petring.db up
```

- Without just:

```bash
pushd migration >/dev/null
mv ../petring.db .
cargo run --release -- up
mv petring.db ../
popd >/dev/null
```

### Finally

- With just:

```bash
just build
```

- Without just:

```bash
cargo build --release --bin petring-api
cargo build --release --bin petring-web
```

> You'll now find the binaries in the `target/release` directory.

### Docker

- Clone the repo
- Initialize the database
- Setup your `.env` file according to the `.env.example` file
- Run migrations
- Edit the docker-compose.yml
  (uncomment/comment out the lines according to what you need.)
- Run the docker-compose

## Contributing

### For people without write access

- Fork the repo
- Check out a new branch based on [dev](https://github.com/h4rldev/petring/tree/dev)
- Make your changes
- Test your changes locally.
<!-- markdownlint-disable MD013 -->
- If you want to be considerate, follow the [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) spec.
- Submit a PR describing what you've done

### For people with write access

- No need to fork the repo, just clone it
- And then follow the same instructions as above
<!-- markdownlint-disable MD013 -->
- When merging auto-prs, also follow the [conventional commits]( spec.

## License

<!-- markdownlint-disable MD013 -->

This project is licensed under the BSD-3 Clause License, see the [LICENSE](LICENSE) file for details.
