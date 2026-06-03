FROM alpine:latest
EXPOSE 8080
WORKDIR /app
RUN wget https://github.com/v2fly/v2ray-core/releases/download/v5.25.0/v2ray-linux-64.zip && unzip v2ray-linux-64.zip && rm v2ray-linux-64.zip && rm config.json
COPY config.json /app
ENTRYPOINT ["./v2ray","run"]
