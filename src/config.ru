#!/usr/bin/env ruby
require 'sinatra'
require 'json'
require 'sinatra/reloader'
require 'async/websocket/adapters/rack'

require 'stack-service-base'

StackServiceBase.rack_setup self

get '*', &-> { slim :index }

run Sinatra::Application