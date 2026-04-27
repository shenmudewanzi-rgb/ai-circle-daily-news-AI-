FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

WORKDIR /app

COPY . /app

EXPOSE 8765

CMD ["pwsh", "-NoLogo", "-File", "/app/docker-entrypoint.ps1"]
