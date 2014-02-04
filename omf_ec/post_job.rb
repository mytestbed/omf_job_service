

# $0 --name foo200 -- simple_test.oedl --more a --foo xx@node -x

require "zlib"
require "json"
require 'optparse'
require 'base64'
require 'net/http'

name = nil
uri = URI.parse('http://localhost:8002/jobs')

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options] -- scriptFile [scriptOptions]"


  opts.on('-n', '--name NAME', 'Name of experiment' ) do |n|
    name = n
  end

  # TODO: Put command-line options here

  # This displays the help screen, all programs are
  # assumed to have this option.
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end
optparse.parse!

# Next argument should be script file
unless ARGV.length >= 1
  puts "ERROR: Missing script file\n"
  puts optparse
  abort
end
scriptFile = ARGV.shift
unless File.readable? scriptFile
  puts "ERROR: Can't read script file '#{scriptFile}'"
  abort
end
bc = Base64.encode64(Zlib::Deflate.deflate(File.read(scriptFile)))
script = {
  type: "application/zip",
  encoding: "base64",
  content: bc.split("\n")
}

# Parse properties
i = 0
properties = []
while i < ARGV.length
  unless (p = ARGV[i]).start_with? '-'
    puts "ERROR: Script arguments need to start with '-'."
    abort
  end
  properties << (prop = {name: p.sub(/^[\-]+/, '')})
  unless (arg = ARGV[i + 1] || '').start_with? '-'
    if (r = arg.split('@')).length > 1
      # resource
      prop[:resource] = rd = {type: 'node'}
      rd[:name] = r[0] unless r[0].empty?
    else
      prop[:value] = arg unless arg.empty?
    end
    i += 1
  end
  #puts ">>> #{p} <#{arg}>"
  i += 1
end

# Create default experiment name if none given
unless name
  require 'etc'
  require 'time'
  name = "exp_#{Etc.getlogin}_#{Time.now.iso8601}"
end

job = {
  name: name,
  oedl_script: script,
  ec_properties: properties
}

puts JSON.pretty_generate(job)

# OK, time ot post it




req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
#req.basic_auth @user, @pass
req.body = JSON.pretty_generate(job)
response = Net::HTTP.new(uri.host, uri.port).start {|http| http.request(req) }
puts "Response #{response.code} #{response.message}: #{response.body}"

