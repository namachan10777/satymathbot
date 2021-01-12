# satymathbot
Receieves math expression via HTTP,
renders it with [SATySFi](https://github.com/gfngfn/SATySFi),
and returns png.

# Build
```
docker build -t <image>:<tag> -f ./dockerfile/prod/Dockerfile .
```

# Run
```
docker run -d --name <name> -p 8080:8080 <image>:<tag>
```
