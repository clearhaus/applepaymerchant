require 'bunny'

bind 'tcp://0.0.0.0:8080'
workers 1
threads 0, 10
quiet true

on_worker_boot do
end
