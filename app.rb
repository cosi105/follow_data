require 'bundler'
require 'json'
Bundler.require

set :port, 8081 unless Sinatra::Base.production?

if Sinatra::Base.production?
  configure do
    redis_uri = URI.parse(ENV['REDISCLOUD_URL'])
    REDIS = Redis.new(host: redis_uri.host, port: redis_uri.port, password: redis_uri.password)
  end
  rabbit = Bunny.new(ENV['CLOUDAMQP_URL'])
else
  REDIS = Redis.new
  rabbit = Bunny.new(automatically_recover: false)
end

rabbit.start
channel = rabbit.create_channel
RABBIT_EXCHANGE = channel.default_exchange

NEW_FOLLOW = channel.queue('new_follow.user_data')
NEW_TWEET = channel.queue('new_tweet.tweet_data')
FOLLOWER_IDS = channel.queue('new_tweet.follower_ids')
SEED = channel.queue('follow.data.seed')

NEW_FOLLOW.subscribe(block: false) do |delivery_info, properties, body|
  parse_follow_data(JSON.parse(body))
end

NEW_FOLLOW.subscribe(block: false) do |delivery_info, properties, body|
  get_follower_ids(JSON.parse(body))
end

SEED.subscribe(block: false) do |delivery_info, properties, body|
  REDIS.flushall
  JSON.parse(body).each { |follow| parse_follow_data(follow) }
end

def parse_follow_data(body)
  follower_id = body['follower_id']
  follower_handle = body['follower_handle']
  followee_id = body['followee_id']
  followee_handle = body['followee_handle']

  REDIS.lpush("#{followee_id}:follower_ids", follower_id)
  REDIS.lpush("#{followee_id}:follower_handles", follower_handle)

  REDIS.lpush("#{follower_id}:followee_ids", followee_id)
  REDIS.lpush("#{follower_id}:followee_handles", followee_handle)
  puts body
end

def get_follower_ids(body)
  author_id = body['author_id']
  tweet_id = body['tweet_id']

  payload = {
    tweet_id: tweet_id,
    follower_ids: REDIS.get("#{author_id}:follower_ids")
  }
  RABBIT_EXCHANGE.publish(payload, routing_key: FOLLOWER_IDS.name)
end
