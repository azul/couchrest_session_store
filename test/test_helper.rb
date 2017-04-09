require 'rubygems'
gem 'minitest'
require 'minitest/autorun'
require_relative '../lib/couchrest_session_store.rb'
require_relative 'couch_tester.rb'

# Create the session db if it does not already exist.
CouchRest::Session::Document.create_database!
