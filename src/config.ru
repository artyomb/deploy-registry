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
  def find_traefik_values(data, main_key, rule_key)
    result = { main: nil, rule: nil }
    case data
    when Hash
      data.each do |_, v|
        sub_result = find_traefik_values(v, main_key, rule_key)
        result[:main] ||= sub_result[:main]
        result[:rule] ||= sub_result[:rule]
      end
    when Array
      data.each do |v|
        if v.is_a?(String)
          v = v.strip
          if v.start_with?(main_key + '=')
            result[:main] = v.split('=', 2).last.strip
          elsif v.start_with?(rule_key + '=')
            result[:rule] = v.split('=', 2).last.strip
          end
        else
          sub_result = find_traefik_values(v, main_key, rule_key)
          result[:main] ||= sub_result[:main]
          result[:rule] ||= sub_result[:rule]
        end
      end
    end
    result
  end
end

def find_traefik_domain(data)
  result = nil
  case data
  when Hash
    data.each do |_, v|
      sub_result = find_traefik_domain(v)
      result ||= sub_result
    end
  when Array
    data.each do |v|
      if v.is_a?(String)
        v = v.strip
        if v.match?(/traefik\.http\.routers\.[^\.]+\.tls\.domains\[0\]\.main=/)
          result = v.split('=', 2).last.strip
          break
        end
      else
        sub_result = find_traefik_domain(v)
        result ||= sub_result
      end
    end
  end
  result
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