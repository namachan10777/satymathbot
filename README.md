# satymathbot

# Build
```
docker build -t <image>:<tag> -f ./dockerfile/prod/Dockerfile .
```

# Run
```
docker run -d --name <name> -p 8080:8080 <image>:<tag>
```
