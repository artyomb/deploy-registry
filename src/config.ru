#!/usr/bin/env ruby
require 'sinatra'
require 'json'
require 'sinatra/reloader'
require 'async/websocket/adapters/rack'

require 'sequel'
DB = Sequel.connect('sqlite://deploy.db')

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

require 'stack-service-base'

StackServiceBase.rack_setup self

get '*', &-> { slim :index }

post '*/api/v1/swarm_deploy' do
  json_params = JSON.parse request.body.read, symbolize_names: true
  deploy = Deploy.new json_params
  deploy.save
  content_type :json
  { status: 'ok' }.to_json
end

run Sinatra::Application