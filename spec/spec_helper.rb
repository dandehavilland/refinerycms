require 'rbconfig'
require 'factory_girl'

if RUBY_VERSION > "1.9"
  require "simplecov"
end

def setup_simplecov
  SimpleCov.start do
    Dir[File.expand_path('../../**/*.gemspec')].map{|g| g.split('/')[-2]}.each do |dir|
      add_group dir.capitalize, "#{dir}/"
    end
    %w(testing config spec vendor).each do |filter|
      add_filter "/#{filter}/"
    end
  end
end

def setup_environment
  # This file is copied to ~/spec when you run 'rails generate rspec'
  # from the project root directory.
  ENV["RAILS_ENV"] ||= 'test'
  setup_simplecov if defined?(SimpleCov) # simplecov should be loaded _before_ models, controllers, etc are loaded.
  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'

  # Requires supporting files with custom matchers and macros, etc,
  # in ./support/ and its subdirectories including factories.
  ([Rails.root] | ::Refinery::Plugins.registered.pathnames).map{|p|
    Dir[p.join('spec', 'support', '**', '*.rb').to_s] +
    Dir[p.join('features/support/factories{/*.rb,*.rb}').to_s]
  }.flatten.each do |support_file|
    require support_file if File.exist?(support_file)
  end

  RSpec.configure do |config|
    # == Mock Framework
    #
    # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
    #
    # config.mock_with :mocha
    # config.mock_with :flexmock
    # config.mock_with :rr
    config.mock_with :rspec

    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, comment the following line or assign false
    # instead of true.
    config.use_transactional_fixtures = true
    config.use_instantiated_fixtures  = false

    config.include ::Devise::TestHelpers, :type => :controller
    config.extend ::Refinery::ControllerMacros, :type => :controller
  end
end

def each_run
end

require 'rubygems'
# If spork is available in the Gemfile it'll be used but we don't force it.
unless (begin; require 'spork'; rescue LoadError; nil end).nil?

  Spork.prefork do
    # Loading more in this block will cause your tests to run faster. However,
    # if you change any configuration or code from libraries loaded here, you'll
    # need to restart spork for it take effect.
    setup_environment
  end

  Spork.each_run do
    # This code will be run each time you run your specs.
    each_run
  end

  # --- Instructions ---
  # - Sort through your spec_helper file. Place as much environment loading
  #   code that you don't normally modify during development in the
  #   Spork.prefork block.
  # - Place the rest under Spork.each_run block
  # - Any code that is left outside of the blocks will be ran during preforking
  #   and during each_run!
  # - These instructions should self-destruct in 10 seconds.  If they don't,
  #   feel free to delete them.
  #
else
  setup_environment
  each_run
end

def capture_stdout(stdin_str = '')
  begin
    require 'stringio'
    $o_stdin, $o_stdout, $o_stderr = $stdin, $stdout, $stderr
    $stdin, $stdout, $stderr = StringIO.new(stdin_str), StringIO.new, StringIO.new
    yield
    {:stdout => $stdout.string, :stderr => $stderr.string}
  ensure
    $stdin, $stdout, $stderr = $o_stdin, $o_stdout, $o_stderr
  end
end
