FROM debian:bullseye-slim

EXPOSE 8080/tcp

COPY . /opt/applepaymerchant/
WORKDIR /opt/applepaymerchant/

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ruby bundler ruby-dev make gcc libc6-dev libssl-dev && \
    bundle install && \
    apt-get --purge remove -y \
        ruby-dev make gcc libc6-dev libssl-dev && \
    apt-get --purge autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

CMD exec bundle exec puma --config config/puma.rb
