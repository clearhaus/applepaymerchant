require 'roda'

require 'cgi'
require 'json'
require 'uri'
require 'net/http'
require 'openssl'

def new_ssl_http_worker(uri, cert, key)
  worker = Net::HTTP.new(uri.host, uri.port)
  worker.use_ssl      = true
  worker.ssl_timeout  = 3
  worker.read_timeout = 3
  worker.open_timeout = 3

  worker.cert        = cert
  worker.key         = key
  worker.ssl_version = :TLSv1_2
  worker.verify_mode = OpenSSL::SSL::VERIFY_PEER

  worker
end

# Implementation of
# https://developer.apple.com/documentation/apple_pay_on_the_web/apple_pay_js_api/requesting_an_apple_pay_payment_session
def do_validation(uri, cert, key, cfg)
  req = Net::HTTP::Post.new(uri)

  data = JSON.generate(
    "merchantIdentifier": cfg['merchantIdentifier'],
    "initiative": 'web',
    "initiativeContext": cfg['initiativeContext'],
    "displayName": cfg['displayName']
  )

  worker = new_ssl_http_worker(uri, cert, key)

  worker.request(req, data)
end

def load_merchant_identity_certificates
  certfile = File.read('merchant_identity.pem')
  cert = OpenSSL::X509::Certificate.new(certfile)

  keyfh = File.open('merchant_identity.key', 'r')
  key = OpenSSL::PKey.read(keyfh)

  [cert, key]
end

def read_configuration(p)
  begin
    contents = File.read(p)
  rescue
    raise "Configuration file #{p} must exist in project root"
  end

  begin
    cfg = JSON.parse(contents)
  rescue
    raise 'Config must be parse as JSON'
  end

  required_keys = %w[merchantIdentifier initiativeContext displayName]
  unless required_keys.map { |x| cfg.key?(x) }.all?
    raise 'Configuration missing keys'
  end

  cfg
end

# ApplePayMerchant is the handler for requests to applepaymerchant.clrhs.dk
# Started by puma.
class ApplePayMerchant < Roda
  plugin :public
  plugin :halt
  plugin :json_parser

  route do |r|
    r.root do
      r.redirect '/index.html'
    end

    # Print the token to standard out.
    r.post 'completesession' do
      puts(r.body.read)
      r.halt(200)
    end

    # Implement
    # https://developer.apple.com/documentation/apple_pay_on_the_web/apple_pay_js_api/requesting_an_apple_pay_payment_session
    r.post 'validatemerchant' do
      @config = read_configuration('config.json')
      # Allowed validationURL's, reference Listing 1 in
      # https://developer.apple.com/documentation/apple_pay_on_the_web/setting_up_your_server
      @url_pattern = /\A(cn-)?apple-pay-gateway-[-a-z0-9]+\.apple\.com\z/
      @cert, @key = load_merchant_identity_certificates

      validation_url = r.POST['validationURL']
      validation_url = CGI.unescape(validation_url) if validation_url

      v_uri = URI.parse(validation_url)

      if @url_pattern.match(v_uri.host).nil?
        r.halt(400, "Invalid validation_url #{validation_url}")
      end

      begin
        applepaysession = do_validation(v_uri, @cert, @key, @config)

        unless applepaysession.is_a?(Net::HTTPSuccess)
          r.halt(applepaysession.code.to_i, 'Apple request failure')
        end

        response.status = 200
        response['Content-Type'] = 'application/json'
        response.write(applepaysession.body)
      rescue OpenSSL::SSL::SSLError => e
        puts("Error connecting to validation url '#{validation_url}':", e.message)
        r.halt(504, 'Error connecting to validation_url')
      rescue => e
        puts("Validation error: #{e.message}")
        r.halt(500, 'Validation Error')
      end
    end

    # Serve 'public/' folder as static files
    r.on do
      r.public
    end
  end
end
