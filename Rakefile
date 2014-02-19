
# Bundler is messing with that later on
GEM_PATH = ENV['GEM_PATH']

# Setup bundler environment
TOP_DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
ENV['BUNDLE_GEMFILE'] = File.join(TOP_DIR, 'Gemfile')
require 'bundler'
Bundler.setup()

require 'yaml'
require 'god'


desc "Starting the Job Service as a daemon"
task :start, :config do |t, args|
  config = args[:config]
  system("/usr/bin/env JOB_CONFIG=#{config} bundle exec god -c etc/omf_job_service.god")
  system('/usr/bin/env bundle exec god start job_service')
end

task :stop do |t, args|
  system('/usr/bin/env bundle exec god stop job_service')
end

task :status, :config do |t, args|
  system('/usr/bin/env bundle exec god status job_service')
end

desc "Call after 'bundle install --path vendor'"
task 'post-install', [:frcp_url] => [:create_server_bin]

task 'create_server_bin' do
  target = 'bin/omf_job_service'
  unless File.readable?("#{target}.in")
    abort "Can't find '#{target}.in' in local directory"
  end
  tmpl = File.read("#{target}.in")

  home = ENV['HOME']
  p home
  gp = ENV['GEM_PATH']
  #p ENV['GEM_HOME']
  #p ENV.keys
  #p gp

  d, ruby, gemset = GEM_PATH.match(/.*(ruby.*)@(.*)/).to_a

  s = tmpl.gsub('%HOME%', home).gsub('%RUBY%', ruby).gsub('%GEMSET%', gemset)
  File.open(target, 'w') do |f|
    f.write(s)
  end
  File.chmod(0755, target)
  puts ".. Created '#{target}'."
end
