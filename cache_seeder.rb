require 'csv'
require 'open-uri'
post '/seed/data' do
  seed_from_csv(REDIS_FOLLOW_DATA, params[:csv_url])
end

post '/seed/html' do
  seed_from_csv(REDIS_FOLLOW_HTML, params[:csv_url])
end

def seed_from_csv(cache, url)
  puts 'Caching...'
  cache.flushall
  whole_csv = CSV.parse(open(url))
  whole_csv.each do |line|
    key = line[0]
    values = line.drop(1)
    cache.rpush(key, values)
  end
  puts "Cached!"
end
