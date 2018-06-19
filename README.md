## Apple Pay Merchant ##

A simple Apple Pay merchant implementation, used for generating tokens for
testing an Apple Pay payment processing gateway. It charges 1DKK, approximately
0.156$ on a provided Apple Pay card.

This setup requires you to set up a forward from your Apple Pay website, with a
valid SSL certificate, to this container. By default port 8080 is used.

### Setup ###

1. **Set up Apple Pay with Apple**

   Apple describes how you can prepare for Apple Pay integration
   [here](https://developer.apple.com/documentation/apple_pay_on_the_web/configuring_your_environment).

2. **Add required certificates**

   The Merchant Identity certificate (signed by Apple) and key must be added to
   the root of the directory as
   - `merchant_identity.pem`
   - `merchant_identity.key`

3. **Create `config.json`**

   The file `config.json.example` contains a list of required keys.

4. **Boot the server with**

   * **Docker-compose**

     Pull the `:latest` container docker image with
     ```bash
     docker pull clearhaus/applepaymerchant
     ```
     Use `docker-compose` to start the container. Token will be printed in the
     output log.
     ```bash
     docker-compose up
     ```

   * **Manual workflow**

     During development/testing, the server can be started inside a docker
     container.

     ```bash
     docker run -ti --rm -v "$PWD:/opt/applepaymerchant" -p 8080:8080 ruby:2.3 bash
     ```

     You need to install dependencies using `bundle install`.
     Start the server with
     ```bash
     bundle exec puma --config config/puma.rb
     ```
5. **Forward Ports**

   Forward traffic from your domain to the container on TCP port 8080. Note that
   your website must have a valid SSL Certificate.

6. **Access Payment Site for testing**

   Visit *https://your.website* on your iPhone or MacOS device,
   click the button that appears. If no Apple Pay button is displayed, your
   browser may not support Apple Pay.

   To set up a sandbox testing account, you can follow
   [this guide](https://developer.apple.com/apple-pay/sandbox-testing/).
