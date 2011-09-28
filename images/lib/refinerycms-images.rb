require 'dragonfly'
require 'rack/cache'
require 'refinerycms-core'

module Refinery
  module Images

    class << self
      attr_accessor :root
      def root
        @root ||= Pathname.new(File.expand_path('../../', __FILE__))
      end
    end

    class Engine < ::Rails::Engine

      initializer 'serve static assets' do |app|
        app.middleware.insert_after ::ActionDispatch::Static, ::ActionDispatch::Static, "#{root}/public"
      end

      initializer 'images-with-dragonfly' do |app|
        app_images = Dragonfly[:images]
        app_images.configure_with(:imagemagick)
        app_images.configure_with(:rails) do |c|
          c.datastore.root_path = Rails.root.join('public', 'system', 'images').to_s
          # /system/images/refinery_is_awesome.jpg?job=BAhbB1sHOgZmIiMyMDEwLzA5LzAxL1NTQ19DbGllbnRfQ29uZi5qcGdbCDoGcDoKdGh1bWIiDjk0MngzNjAjYw
          c.url_format = '/system/images/:prefix/:basename.:format'
          c.secret = RefinerySetting.find_or_set(:dragonfly_secret,
                                                Array.new(24) { rand(256) }.pack('C*').unpack('H*').first)
        end
        
        app_images.server.url_format = '/system/images/:prefix/:basename.:format'

        if Refinery.s3_backend
          app_images.configure_with(:heroku, ENV['S3_BUCKET'])
          # Dragonfly doesn't set the S3 region, so we have to do this manually
          app_images.datastore.configure do |d|
            d.region = ENV['S3_REGION'] if ENV['S3_REGION'] # otherwise defaults to 'us-east-1'
          end
        end

        app_images.define_macro(ActiveRecord::Base, :image_accessor)
        app_images.analyser.register(Dragonfly::ImageMagick::Analyser)
        app_images.analyser.register(Dragonfly::Analysis::FileCommandAnalyser)

        ### Extend active record ###

        app.config.middleware.insert_after 'Rack::Lock', 'Dragonfly::Middleware', :images

        app.config.middleware.insert_before 'Dragonfly::Middleware', 'Rack::Cache', {
          :verbose     => Rails.env.development?,
          :metastore   => "file:#{Rails.root.join('tmp', 'dragonfly', 'cache', 'meta')}",
          :entitystore => "file:#{Rails.root.join('tmp', 'dragonfly', 'cache', 'body')}"
        }
      end

      config.after_initialize do
        ::Refinery::Plugin.register do |plugin|
          plugin.pathname = root
          plugin.name = 'refinery_images'
          plugin.directory = 'images'
          plugin.version = %q{1.0.0}
          plugin.menu_match = /(refinery|admin)\/image(_dialog)?s$/
          plugin.activity = {
            :class => Image
          }
        end
      end
    end
  end
end

::Refinery.engines << 'dashboard'
