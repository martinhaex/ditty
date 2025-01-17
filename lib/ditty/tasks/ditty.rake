# frozen_string_literal: true

require 'fileutils'

namespace :ditty do
  desc 'Run the ditty console'
  task :console do
    require 'irb'
    ARGV.clear
    IRB.start
  end

  desc 'Prepare Ditty'
  task prep: ['generate_tokens', 'prep:folders', 'prep:public', 'prep:migrations']

  desc 'Generate the needed tokens'
  task :generate_tokens do
    puts 'Generating the Ditty tokens'
    require 'securerandom'
    File.write('.session_secret', SecureRandom.random_bytes(40)) unless File.file?('.session_secret')
    File.write('.token_secret', SecureRandom.random_bytes(40)) unless File.file?('.token_secret')
  end

  desc 'Seed the Ditty database'
  task :seed do
    puts 'Seeding the Ditty database'
    require 'ditty/seed'
  end

  desc 'Dump the Ditty DB Schema'
  task :dump_schema do
    Ditty::Components.components.each do |_name, comp|
      comp.load if comp.respond_to?(:load)
    end.compact
    DB.dump_schema_cache('./config/schema.dump')
  end

  namespace :prep do
    desc 'Create a user'
    task :user, [:email, :password] do |_t, args|
      require 'ditty/listener'

      identity = Ditty::Identity.new(username: args[:email], password: args[:password])
      identity.password_confirmation = identity.password
      user = Ditty::User.new(email: identity.username)
      begin
        identity.valid?
        DB.transaction do
          user.save_changes
          user.add_identity identity
          Ditty::Listener.new.user_register(target: self, values: { user: user })
        end
      rescue StandardError => e
        Ditty::Services::Logger.error "Could not regster super user: #{e.message}"
        Ditty::Services::Logger.debug e
      end
    end

    desc 'Check that the required Ditty folders are present'
    task :folders do
      puts 'Prepare the Ditty folders'
      FileUtils.mkdir_p 'pids'
      FileUtils.mkdir_p 'logs'
    end

    desc 'Check that the public folder is present and populated'
    task :public do
      puts 'Preparing the Ditty public folder'
      FileUtils.mkdir_p 'public'
      ::Ditty::Components.public_folder.each do |path|
        puts "Checking #{path}"
        path = "#{path}/."
        FileUtils.cp_r path, 'public' unless File.expand_path(path).eql? File.expand_path('public')
      end
    end

    desc 'Check that the migrations folder is present and populated'
    task :migrations do
      puts 'Preparing the Ditty migrations folder'
      FileUtils.mkdir_p 'migrations'
      ::Ditty::Components.migrations.each do |path|
        path = "#{path}/."
        FileUtils.cp_r path, 'migrations' unless File.expand_path(path).eql? File.expand_path('migrations')
      end
      puts 'Migrations added:'
      Dir.foreach('migrations').sort.each { |x| puts x if File.file?("migrations/#{x}") && x[-3..] == '.rb' }
    end
  end

  desc 'Migrate Ditty database to latest version'
  task migrate: ['prep:migrations'] do
    puts 'Running the Ditty migrations'
    Rake::Task['ditty:migrate:up'].invoke
  end

  namespace :migrate do
    require 'logger'

    folder = 'migrations'

    desc 'Check if the migration is current'
    task :check do
      ::DB.loggers << Logger.new($stdout) if ::DB.loggers.count.zero?
      puts '** [ditty] Running Ditty Sequel Migrations check'
      ::Sequel.extension :migration
      begin
        ::Sequel::Migrator.check_current(::DB, folder)
        puts '** [ditty] Sequel Migrations up to date'
      rescue Sequel::Migrator::Error => _e
        raise 'Sequel Migrations NOT up to date'
      end
    end

    desc 'Migrate Ditty database to the specified version'
    task :run, [:version] do |_t, args|
      ::DB.loggers << Logger.new($stdout) if ::DB.loggers.count.zero?
      raise 'No version specified' unless args[:version]

      puts "** [ditty] Running Ditty Migrations to #{args[:version]}"
      ::Sequel.extension :migration
      ::Sequel::Migrator.run(::DB, folder, target: args[:version].to_i)
    end

    desc 'Migrate Ditty database to latest version'
    task :up do
      ::DB.loggers << Logger.new($stdout) if ::DB.loggers.count.zero?
      puts '** [ditty] Running Ditty Migrations up'
      ::Sequel.extension :migration
      ::Sequel::Migrator.apply(::DB, folder)
    end

    desc 'Remove the whole Ditty database. You WILL lose data'
    task :down do
      ::DB.loggers << Logger.new($stdout) if ::DB.loggers.count.zero?
      puts '** [ditty] Running Ditty Migrations down'
      ::Sequel.extension :migration
      ::Sequel::Migrator.apply(::DB, folder, 0)
    end

    desc 'Reset the Ditty database. You WILL lose data'
    task :bounce do
      ::DB.loggers << Logger.new($stdout) if ::DB.loggers.count.zero?
      puts '** [ditty] Running Ditty Migrations bounce'
      ::Sequel.extension :migration
      ::Sequel::Migrator.apply(::DB, folder, 0)
      ::Sequel::Migrator.apply(::DB, folder)
    end
  end
end
