source 'https://rubygems.org'

gem 'rails-controller-testing'

# Pinned to the released 5.6.x line (matching spree_host), same rationale as
# spree_square's and spree_doordash's Gemfiles.
spree_opts = if ENV['SPREE_PATH']
                { 'path': ENV['SPREE_PATH'] }
             else
                '~> 5.6.0'
             end
gem 'spree', spree_opts
gem 'spree_admin', spree_opts

gem 'spree_dev_tools', '>= 0.6.0.rc1'

if ENV['DB'] == 'mysql'
  gem 'mysql2'
elsif ENV['DB'] == 'postgres'
  gem 'pg'
else
  gem 'sqlite3'
end

gem 'propshaft'

gemspec
