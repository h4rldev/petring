# PetRing & PetAds

> [!WARNING]
> This project is in an early ALPHA and is not ready for any serious usecase
> Bugs will exist, and code will be messy; Keep that in mind.

This is a webring and navlink ad system for the Jess Museum Discord server.

## How to build

### Prerequisites

- Just
- A stable rust toolchain
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

```bash
just migrations petring.db up
```

### Finally

```bash
just build
```

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
- If you want to be considerate, follow the [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) spec.
- Submit a PR describing what you've done

### For people with write access

- No need to fork the repo, just clone it
- And then follow the same instructions as above

## License

This project is licensed under the BSD-3 Clause License, see the [LICENSE](LICENSE) file for details.
