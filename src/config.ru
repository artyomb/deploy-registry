#!/usr/bin/env ruby
require 'sinatra'
require 'json'
require 'sinatra/reloader'
require 'async/websocket/adapters/rack'

require 'sequel'
DB = Sequel.connect('sqlite:///data/deploy.db')

DB.create_table? :deploys do
  primary_key :id
  String      :deploy_host
  String      :docker_context
  String      :deploy_command
  String      :stack_name
  String      :deploy_status
  String      :stack, text: true

  DateTime :created_at, null: false, default: Sequel.lit('NOW()')
  DateTime :updated_at, null: false, default: Sequel.lit('NOW()')
end

class Deploy < Sequel::Model
  plugin :validation_helpers
  plugin :timestamps, create: :created_at, update: :updated_at, update_on_create: true
end

helpers do
  def find_traefik_string(obj)
    case obj
    when Hash
      obj.values.each { |v| result = find_traefik_string(v); return result if result }
    when Array
      obj.each { |v| result = find_traefik_string(v); return result if result }
    when String
      return obj if obj.match?(/traefik\.http\.routers\..*\.tls\.domains\[0\]\.main=.+/)
    end
    nil
  end
end

require 'stack-service-base'

StackServiceBase.rack_setup self

get '/', &-> { slim :index }

get '/stacks', &-> { slim :stacks }
get '/servers', &-> { slim :servers }
get '/host', &-> { slim :host }
get '/stack', &-> { slim :stack }
get '/inspect', &-> { slim :inspect }

post '*/api/v1/swarm_deploy' do
  json_params = JSON.parse request.body.read, symbolize_names: true
  json_params[:stack] = json_params[:stack].to_json
  deploy = Deploy.new json_params
  deploy.save
  content_type :json
  { status: 'ok' }.to_json
end

run Sinatra::Application