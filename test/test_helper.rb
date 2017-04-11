require 'minitest/autorun'
require 'active_support'
require 'active_support/core_ext'

# make sure we require our own lib rather than an installed gem
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
