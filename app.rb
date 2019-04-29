require 'bundler'
require 'json'
Bundler.require

set :port, 8081 unless Sinatra::Base.production?

if Sinatra::Base.production?
  configure do
    REDIS_FOLLOW_DATA = redis_from_uri('FOLLOW_DATA')
    REDIS_FOLLOW_HTML = redis_from_uri('FOLLOW_HTML')
  end
  rabbit = Bunny.new(ENV['CLOUDAMQP_URL'])
else
  REDIS_FOLLOW_DATA = Redis.new(port: 6385)
  REDIS_FOLLOW_HTML = Redis.new(port: 6380)
  rabbit = Bunny.new(automatically_recover: false)
end

rabbit.start
channel = rabbit.create_channel
RABBIT_EXCHANGE = channel.default_exchange

new_follow = channel.queue('new_follow.user_data')
new_tweet = channel.queue('new_tweet.tweet_data')
seed = channel.queue('follow.data.seed')
FOLLOWER_IDS = channel.queue('new_tweet.follower_ids')

new_follow.subscribe(block: false) do |delivery_info, properties, body|
  parse_follow_data(JSON.parse(body))
end

new_tweet.subscribe(block: false) do |delivery_info, properties, body|
  get_follower_ids(JSON.parse(body))
end

seed.subscribe(block: false) do |delivery_info, properties, body|
  REDIS_FOLLOW_DATA.flushall
  JSON.parse(body).each { |follow| parse_follow_data(follow) }
end

def redis_from_uri(key)
  uri = URI.parse(ENV[key])
  Redis.new(host: uri.host, port: uri.port, password: uri.password)
end

def parse_follow_data(body)
  follower_id = body['follower_id'].to_i
  followee_id = body['followee_id'].to_i
  REDIS_FOLLOW_DATA.lpush("#{followee_id}:follower_ids", follower_id)
  REDIS_FOLLOW_DATA.lpush("#{follower_id}:followee_ids", followee_id)

  followee_handle = body['followee_handle']
  follower_handle = body['follower_handle']
  REDIS_FOLLOW_HTML.lpush("#{follower_id}:followees", "<li>#{followee_handle}</li>")
  REDIS_FOLLOW_HTML.lpush("#{followee_id}:followers", "<li>#{follower_handle}</li>")
  puts "Parsed #{follower_handle} -> #{followee_handle}"
end

def get_follower_ids(body)
  author_id = body['author_id']
  tweet_id = body['tweet_id']

  payload = {
    tweet_id: tweet_id,
    follower_ids: REDIS_FOLLOW_DATA.lrange("#{author_id}:follower_ids", 0, -1)
  }.to_json
  RABBIT_EXCHANGE.publish(payload, routing_key: FOLLOWER_IDS.name)
end
