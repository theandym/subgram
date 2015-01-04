# Config
require 'sinatra'
require 'instagram'
require 'redis'
require 'date'
require 'json'

configure { set :server, :puma }


# Redis setup
if ENV.has_key?( ENV['REDIS_URL'] )
  redis_url = ENV[ ENV['REDIS_URL'] ]
else
  redis_url = ENV['REDIS_URL']
end

redis = Redis.new(:url => redis_url)


# Instagram setup
Instagram.configure do |config|
  config.client_id = ENV['INSTAGRAM_CLIENT_ID']
  config.client_secret = ENV['INSTAGRAM_CLIENT_SECRET']
end

client = Instagram.client

username = ENV['INSTAGRAM_USERNAME']
start_date = ENV['INSTAGRAM_START_DATE']
hashtag = ENV['INSTAGRAM_HASHTAG']


# Index
get '/' do

  redis_content = redis.get('images')
  @images = JSON.parse(redis_content)

  @username = username
  @hashtag = hashtag

  erb :index

end


# Update
get '/update' do

  users = client.user_search(username)
  user_hash = users.select { |user| user['username'] == username }
  user = user_hash.first

  recent_media = client.user_recent_media(user['id'])
  
  redis_content = redis.get('images')

  if !redis_content.nil?
    images = JSON.parse(redis_content)
  else
    images = []
  end

  recent_media.each do |item|
    after_start_date = ( Time.at(item['created_time'].to_i).utc.to_datetime >= DateTime.parse(start_date) )
    is_image = item['type'] == 'image'
    has_text = item['caption'] && item['caption']['text'] && item['caption']['text'][hashtag]

    if after_start_date && is_image && has_text
      images << {
        'id' => item['id'],
        'images' => { 
          'thumbnail' => {
            'url' => item['images']['thumbnail']['url']
            } 
          },
        'created_time' => item['created_time']
        }
    end
  end

  images = images.uniq
  images = images.sort_by{ |item| item['created_time'] }

  redis.set('images', images.to_json)

end
