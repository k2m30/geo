# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'maxmind/geoip2'
require 'redis'
require 'json'
require 'digest'

def store_to_redis(user_id, request)
  remote_ip = request['REMOTE_ADDR']
  remote_ip = '5.173.252.127' if remote_ip == '::1' or remote_ip == '127.0.0.1'
  remote_ip = remote_ip&.gsub(/::ffff:/, '')
  puts remote_ip
  reader = MaxMind::GeoIP2::Reader.new('./GeoLite2-City.mmdb')
  record = reader.city(remote_ip)
  reader = MaxMind::GeoIP2::Reader.new('./GeoLite2-ASN.mmdb')
  asn = reader.asn(remote_ip)
  info = {
    agent: request['HTTP_USER_AGENT'],
    city: record.city&.names&.[]('en'),
    district: record.most_specific_subdivision&.names&.[]('en'),
    url: "https://www.google.com/maps/place/#{record.location&.latitude},#{record.location&.longitude}",
    remote_ip: remote_ip,
    asn: asn.autonomous_system_number,
    asn_org: asn.autonomous_system_organization,
    asn_network: asn.network,
  }
  Redis.new.set(user_id.gsub('@', ''), append(user_id, info).to_json)
end

def append(user_id, info)
  existing_info = Redis.new.get(user_id)
  hash = Digest::SHA256.hexdigest info.to_s

  if existing_info
    existing_info = JSON[existing_info, symbolize_names: true]

    if existing_info[hash.to_sym]
      existing_info[hash.to_sym][:visits] += 1
    else
      existing_info[hash.to_sym] = { info: info, visits: 1 }
    end
    existing_info
  else
    { hash.to_sym => { info: info, visits: 1 } }
  end
end

configure do
  set :environment, :production
  set :bind, '::'
  set :port, 80
  set :server, 'thin'
end

get '/' do
  status 404
  body 'nothing is here'
end

get '/:user_id' do
  redis = Redis.new
  user_id = params['user_id']
  users = JSON[redis.get('users') || '[]']
  if users.include? user_id
    store_to_redis(user_id, request.env)
    erb :'index.html', format: :html5, locals: { user_id: user_id }
  else
    status 404
    body 'nothing is here'
  end
end

get '/new/:user_id' do
  redis = Redis.new
  users = JSON[redis.get('users') || '[]']
  users = users.insert(-1, params['user_id']).compact.uniq
  redis.set('users', users)
end

get '/u/:user_id' do
  redis = Redis.new
  user_id = params['user_id']
  users = JSON[redis.get('users') || '[]']
  if users.include? user_id
    @user_id = params['user_id']&.gsub('@', '')
    @stats = JSON[redis.get(@user_id), symbolize_names: true]
    @stats = { hash: { info: {}, visits: 0 } } if @stats == 'null'
    erb :'stats.html', { locals: { user_id: @user_id, stats: @stats } }
  else
    status 404
    body 'nothing is here'
  end
end
