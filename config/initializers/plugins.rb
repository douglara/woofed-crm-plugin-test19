# frozen_string_literal: true

# Load plugins and sync storage/build/ on boot.
# The build folder is the single mechanism for extending all file types.

Rails.application.config.after_initialize do
  next if defined?(Rails::Generators) # skip during generators

  Plugins::PluginLoader.load_all!

  # Draw plugin routes into the main router.
  Plugins::PluginLoader.loaded_plugins.each do |plugin|
    routes_file = plugin.path.join("config", "routes.rb")
    next unless routes_file.exist?

    Rails.application.routes.draw do
      instance_eval(File.read(routes_file))
    end
  end
end
