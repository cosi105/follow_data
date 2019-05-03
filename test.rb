# This file is a DRY way to set all of the requirements
# that our tests will need, as well as a before statement
# that purges the database and creates fixtures before every test

ENV['APP_ENV'] = 'test'
require 'simplecov'
SimpleCov.start
require 'minitest/autorun'
require './app'
require 'pry-byebug'

def app
  Sinatra::Application
end

def publish_follow(follow)
  RABBIT_EXCHANGE.publish(follow.to_json, routing_key: 'new_follow.data')
end

def publish_tweet(tweet)
  RABBIT_EXCHANGE.publish(tweet.to_json, routing_key: 'new_tweet.follow.tweet_data')
end

def get_list(cache, key)
  cache.lrange(key, 0, -1).sort
end

describe 'NanoTwitter' do
  before do
    REDIS_FOLLOW_DATA.flushall
    REDIS_FOLLOW_HTML.flushall
    @follow1 = { followee_id: 1, followee_handle: '@ari', follower_id: 2, follower_handle: '@brad' }
    @follow2 = { followee_id: 1, followee_handle: '@ari', follower_id: 3, follower_handle: '@yang' }
    @tweet = { tweet_id: 1, author_id: 1 }
  end

  it 'can cache information about a follow' do
    parse_follow_data JSON.parse @follow1.to_json
    get_list(REDIS_FOLLOW_DATA, '1:follower_ids').must_equal ['2']
    get_list(REDIS_FOLLOW_DATA, '2:followee_ids').must_equal ['1']
    get_list(REDIS_FOLLOW_HTML, '1:followers').must_equal ['<li>@brad</li>']
    get_list(REDIS_FOLLOW_HTML, '2:followees').must_equal ['<li>@ari</li>']
  end

  it 'can get a follow from queue' do
    publish_follow @follow1
    sleep 3
    get_list(REDIS_FOLLOW_DATA, '1:follower_ids').must_equal ['2']
    get_list(REDIS_FOLLOW_DATA, '2:followee_ids').must_equal ['1']
    get_list(REDIS_FOLLOW_HTML, '1:followers').must_equal ['<li>@brad</li>']
    get_list(REDIS_FOLLOW_HTML, '2:followees').must_equal ['<li>@ari</li>']
  end

  it 'can handle multiple follows' do
    publish_follow @follow1
    publish_follow @follow2
    sleep 3
    get_list(REDIS_FOLLOW_DATA, '1:follower_ids').must_equal %w[2 3]
    get_list(REDIS_FOLLOW_DATA, '2:followee_ids').must_equal ['1']
    get_list(REDIS_FOLLOW_DATA, '3:followee_ids').must_equal ['1']
    get_list(REDIS_FOLLOW_HTML, '1:followers').sort.must_equal %w[<li>@brad</li> <li>@yang</li>]
    get_list(REDIS_FOLLOW_HTML, '2:followees').must_equal ['<li>@ari</li>']
    get_list(REDIS_FOLLOW_HTML, '3:followees').must_equal ['<li>@ari</li>']
  end

  it 'can identify tweet fanout targets' do
    publish_follow @follow1
    publish_follow @follow2
    sleep 3
    get_follower_ids JSON.parse(@tweet.to_json)
    sleep 3
    msg_json = JSON.parse FOLLOWER_IDS_TIMELINE_DATA.pop.last
    msg_json_2 = JSON.parse FOLLOWER_IDS_TIMELINE_HTML.pop.last
    msg_json.must_equal msg_json_2
    msg_json['tweet_id'].must_equal 1
    msg_json['follower_ids'].sort.must_equal %w[2 3]
  end

  it 'can fan out tweet from queue' do
    publish_follow @follow1
    publish_follow @follow2
    sleep 3
    publish_tweet @tweet
    sleep 3
    msg_json = JSON.parse FOLLOWER_IDS_TIMELINE_DATA.pop.last
    msg_json_2 = JSON.parse FOLLOWER_IDS_TIMELINE_HTML.pop.last
    msg_json.must_equal msg_json_2
    msg_json['tweet_id'].must_equal 1
    msg_json['follower_ids'].sort.must_equal %w[2 3]
  end
end
