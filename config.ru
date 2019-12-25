require 'rubygems'
require 'bundler'

Bundler.require

require './pyssla'
run Sinatra::Application
