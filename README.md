# PetRing & PetAds

This is a webring and navlink ad system for the Jess Museum Discord server.

## How to build

### Prerequisites

- Just
- rust, cargo and stuffs
- sqlite
- openssl (for generating random keys)

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

## Docker

- Clone the repo
- Initialize the database
- Setup your `.env` file according to the `.env.example` file
- Run migrations
- Run the docker-compose

## License

This project is licensed under the BSD-3 Clause License -
see the [LICENSE](LICENSE) file for details.
