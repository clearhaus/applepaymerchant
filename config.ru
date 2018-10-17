require 'bunny'

require File.expand_path('../merchant.rb', __FILE__)

begin
  bunny = Bunny.new(host: 'rabbitmq')
  bunny.start
  ch = bunny.create_channel
  $q = ch.queue('applepaymerchant.tokens', auto_delete: true)

  $x = ch.default_exchange
rescue
  puts('Unable to connect to RabbitMQ')
end

run ApplePayMerchant.app
