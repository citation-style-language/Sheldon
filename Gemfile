source 'https://rubygems.org'
ruby '2.2.2'

gem 'sinatra', '~>1.4'
gem 'sinatra-contrib', '~>1.4'
gem 'erubis', '~>2.7'
gem 'octokit', '~>4.0'

group :development, :test do
  gem 'rake', '~>10.0'
  gem 'rack-test', '~>0.6'
  gem 'minitest', '~>5.6'
end

group :debug do
  gem 'byebug', platforms: :mri
end

group :production do
  gem 'puma', '~>2.11'
  gem 'foreman', '~>0.78'
end
