require 'rubygems'
require 'bundler/setup'
require 'split'

def session
  @session ||= {}
end

def params
  @params ||= {}
end