root = File.expand_path('..', __dir__)

workers 3

directory root
rackup File.join(root, 'config.ru')
# bind 'tcp://0.0.0.0:9292'
bind "unix:///home/isucon/webapp/ruby/tmp/puma.sock"
environment ENV.fetch('RACK_ENV') { 'development' }
pidfile File.join(root, 'tmp', 'puma.pid')

preload_app!
wait_for_less_busy_worker 0.005
nakayoshi_fork true
log_requests false
