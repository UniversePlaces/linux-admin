# Linux scripts

## Configure some basic stuff on Linux server

```sh
curl -sSL https://raw.githubusercontent.com/UniversePlaces/linux-admin/refs/heads/main/1-init-server.sh | bash
```

## Install and configure tipi

```sh
curl -sSL -o setup-tipi.sh https://raw.githubusercontent.com/UniversePlaces/linux-admin/refs/heads/main/2-install-tipi.sh && chmod +x setup-tipi.sh && ./setup-tipi.sh && rm setup-tipi.sh
```
