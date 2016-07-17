# Redis
# https://github.com/redis/redis-rb
#$redis = Redis.new(:host => 'localhost', :port => 6379)
redis = Redis.new(:path => "/tmp/redis.sock")
