source "https://rubygems.org"

def override_with_local(local_dir)
  unless local_dir.start_with? '/'
    local_dir = File.join(File.dirname(__FILE__), local_dir)
  end
  #puts "Checking for '#{local_dir}'"
  Dir.exist?(local_dir) ? {path: local_dir} : {}
end

gem 'systemu'
gem 'omf_base', override_with_local('../omf_base')
gem 'omf_sfa', override_with_local('../omf_sfa')
