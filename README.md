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
- Go into the docker-compose.yml and uncomment/comment out the lines according to what you need.
- Run the docker-compose

## Contributing

> [!NOTE]
> As of the 21st of October, 2025, your commits require squashing for a valid PR.

### For people without write access

- Fork the repo
- Check out a new branch
- Depending on what you're contributing to,
  checkout something based on either of following branches:
  - [backend](https://github.com/h4rldev/petring/tree/backend)
  - [frontend](https://github.com/h4rldev/petring/tree/frontend)
- If its not related to either of the above, base your fork branch on [main](https://github.com/h4rldev/petring/tree/main)
- Make your changes
- Submit a PR to the relevant branch you checked out from
  describing your changes.

### For people with write access

- No need to fork the repo, just clone it
- And then follow the same instructions as above

## License

This project is licensed under the BSD-3 Clause License -
see the [LICENSE](LICENSE) file for details.
