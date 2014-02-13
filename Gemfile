source "https://rubygems.org"

def override_with_local(local_dir)
  unless local_dir.start_with? '/'
    local_dir = File.join(File.dirname(__FILE__), local_dir)
  end
  #puts "Checking for '#{local_dir}'"
  Dir.exist?(local_dir) ? {path: local_dir} : {}
end

gem 'omf_base', override_with_local('../omf_base')
gem 'omf_sfa', override_with_local('../omf_sfa')
# TODO: this is to install a local EC in the job service
# vendor directory in order to use it inside ExecApp
# (there must be a way to use the one in the omf_ec subdir
# but I could not figure it out quickly and had to do without)
gem 'omf_ec', ">= 6.0.8.pre"

# they shouldn't be here
