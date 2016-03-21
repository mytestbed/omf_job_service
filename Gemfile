source "https://rubygems.org"

def override_with_local(local_dir, opts = {})
  unless local_dir.start_with? '/'
    local_dir = File.join(File.dirname(__FILE__), local_dir)
  end
  #puts "Checking for '#{local_dir}'"
  Dir.exist?(local_dir) ? {path: local_dir} : opts
end

gem 'omf_base', override_with_local('../omf_base')
#gem 'omf_sfa', "= 0.2.3"
gem 'omf_sfa', "~> 0.2.3"
gem 'god'

gem 'thin_async'
gem "pg"
gem "em-pg-client", "~> 0.2.1", :require => ['pg/em', 'em-synchrony/pg']
gem "em-pg-sequel"

# Cross domain request
gem 'rack-cors', :require => 'rack/cors'

# TODO: Check if this is still needed. New macaddr gem forgot that
gem 'systemu'

group "verification" do
  gem "rserve-client"
end
