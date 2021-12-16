# satymathbot

![Test](https://github.com/namachan10777/satymathbot/workflows/Test/badge.svg)

Receieves math expression via HTTP,
renders it with [SATySFi](https://github.com/gfngfn/SATySFi),
and returns png.

## Test

```bash
make docker-compose-core
# access to http://localhost:8080/$(echo "1 + 1" | base64).png
```
