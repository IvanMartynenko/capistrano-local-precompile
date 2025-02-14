namespace :load do
  task :defaults do
    set :assets_dir,       'public/assets'
    set :packs_dir,        'public/packs'
    set :rsync_cmd,        'rsync -av --delete'
    set :assets_role,      'web'

    after 'bundler:install', 'deploy:assets:prepare'
    after 'deploy:assets:prepare', 'deploy:assets:rsync'
    # after 'deploy:assets:rsync', 'deploy:assets:cleanup'
  end
end

namespace :deploy do
  namespace :assets do
    desc 'Remove all local precompiled assets'
    task :cleanup do
      run_locally do
        # execute 'rm', '-rf', "#{fetch(:packs_dir)}/*"
      end
    end

    desc 'Actually precompile the assets locally'
    task :prepare do
      run_locally do
        precompile_env = fetch(:precompile_env) || fetch(:rails_env) || 'production'
        with rails_env: precompile_env do
          # execute 'rake', 'shakapacker:clean'
          # execute 'rm', '-rf', "#{fetch(:packs_dir)}/*"
          execute 'rails', 'shakapacker:compile'
        end
      end
    end

    desc 'Performs rsync to app servers'
    task :rsync do
      on roles(fetch(:assets_role)), in: :parallel do |server|
        run_locally do
          remote_shell = %(-e "ssh -p #{server.port}") if server.port

          packs_dir = fetch(:packs_dir)
          remount_path = "#{server.user}@#{server.hostname}:#{current_path}/#{packs_dir}/"
          command = Dir.exist?(packs_dir) ? "#{fetch(:rsync_cmd)} #{remote_shell} ./#{packs_dir}/ #{remount_path}" : nil
          return if command.nil?

          if dry_run?
            SSHKit.config.output.info command
          else
            execute command
          end
        end
      end
    end
  end
end
