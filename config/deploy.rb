# config valid only for Capistrano 3.1
lock "3.2.1"

set :application, "publify"
set :repo_url, "git@github.com:framgia/publify.git"
set :assets_roles, [:app]
set :deploy_ref, (ENV["DEPLOY_REVISION"] || ENV["DEPLOY_BRANCH"])

if fetch(:deploy_ref)
  set :branch, fetch(:deploy_ref)
else
  raise "Please set $DEPLOY_REVISION or $DEPLOY_BRANCH."
end

set :deploy_to, "/usr/local/rails_apps/#{fetch :application}"
set :pid_file, "#{shared_path}/tmp/pids/unicorn.pid"

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w{config/database.yml}

# Default value for linked_dirs is []
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for default_env is {}
set :default_env, {
  rails_env: ENV["RAILS_ENV"],
  database_host: ENV["DATABASE_HOST"],
  database_username: ENV["DATABASE_USERNAME"],
  database_password: ENV["DATABASE_PASSWORD"]
}

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :deploy do
  desc "upload files"
  task :upload do
    on roles(:app) do |host|
      upload! "config/database.yml.production",
        "#{shared_path}/config/database.yml"
      upload! "config/mail.yml.production",
        "#{shared_path}/config/mail.yml"
    end
  end
  before "deploy:check:linked_files", :upload

  desc "create database"
  task :create_database do
    on roles(:db) do |host|
      within "#{release_path}" do
        with rails_env: ENV["RAILS_ENV"] do
          execute :rake, "db:create"
        end
      end
    end
  end
  before :migrate, :create_database

  desc "seed database"
  task :seed_database do
    on roles(:db) do |host|
      within "#{release_path}" do
        with rails_env: ENV["RAILS_ENV"] do
          execute :rake, "db:seed"
        end
      end
    end
  end
  after :migrate, :seed_database

  desc "Restart application"
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute "if test -f #{fetch :pid_file}; then kill -USR2 `cat #{fetch :pid_file}`; fi"
    end
  end
  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end
