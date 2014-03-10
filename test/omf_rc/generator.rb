#!/usr/bin/env ruby

require 'oml4r'
#puts OML4R::VERSION

# Define your own Measurement Points
class SinMP < OML4R::MPBase
  name :sin
  param :label
  param :angle, :type => :int32
  param :value, :type => :double
end

class CosMP < OML4R::MPBase
  name :cos
  param :label
  param :value, :type => :double
end

# Initialise the OML4R module for your application
# 'collect' could also be tcp:host:port
opts = {:appName => 'generator', :domain => 'foo', :collect => 'file:-'}

begin
  OML4R::init(ARGV, opts)
rescue OML4R::MissingArgumentException => mex
  $stderr.puts mex
  exit
end

freq = 2.0 # Hz
inc = 15 # rad
# Now collect and inject some measurements
500.times do |i|
  sleep 1./freq
  angle = inc * i
  SinMP.inject("label_#{angle}", angle, Math.sin(angle))
  CosMP.inject("label_#{angle}", Math.cos(angle))
end

# Don't forget to close when you are finished
OML4R::close()
