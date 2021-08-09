require 'sinatra'
require 'sinatra/reloader'
require 'maxmind/geoip2'
require 'redis'

def store_to_redis(nickname, request)
  remote_ip = request['REMOTE_ADDR']
  remote_ip = '5.173.252.128' if remote_ip == '::1' or remote_ip == '127.0.0.1'
  remote_ip = remote_ip.gsub(/::ffff:/, '')
  reader = MaxMind::GeoIP2::Reader.new('./GeoLite2-City.mmdb')
  record = reader.city(remote_ip)
  reader = MaxMind::GeoIP2::Reader.new('./GeoLite2-ASN.mmdb')
  asn = reader.asn(remote_ip)
  Redis.new.set(nickname.gsub('@', ''),
                "#{record.city.names['ru']} http://www.google.com/maps/place/#{record.location.latitude},#{record.location.longitude}
                #{record.most_specific_subdivision&.names['ru']}\n #{request['REMOTE_ADDR']} #{request}
                #{asn.autonomous_system_number} #{asn.autonomous_system_organization} #{asn.network}")
end

configure do
  set :environment, :production
  set :bind, '::'
  set :port, 80 unless development?
  set :server, 'thin'
end

get '/' do
  nickname = params['u'] || 'k2m30'
  store_to_redis(nickname, request.env)
  erb :'index.html', format: :html5
end

get '/u/:nickname' do
  Redis.new.get(params['nickname'].gsub('@', '')) || 'Not found'
end
