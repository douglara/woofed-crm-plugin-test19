# frozen_string_literal: true

module Plugins
  # Discovers and loads plugins from the storage/plugins/ directory.
  #
  # Each plugin has a manifest at storage/plugins/<name>/plugin.rb that defines
  # name, version, and priority.
  class PluginLoader
    PluginManifest = Struct.new(:name, :version, :priority, :path, keyword_init: true)

    class << self
      def loaded_plugins
        @loaded_plugins ||= []
      end

      def reset!
        @loaded_plugins = []
      end

      # Discover and load all plugins, then sync the build.
      def load_all!(root: Rails.root)
        reset!
        discover_plugins(root)
        load_plugin_routes!(root)
        sync_build!(root)
      end

      private

      def discover_plugins(root)
        plugins_dir = root.join("storage", "plugins")
        return unless plugins_dir.exist?

        plugins_dir.children.select(&:directory?).sort.each do |plugin_dir|
          manifest_path = plugin_dir.join("plugin.rb")
          next unless manifest_path.exist?

          manifest = parse_manifest(manifest_path, plugin_dir)
          loaded_plugins << manifest if manifest
        end

        loaded_plugins.sort_by!(&:priority)
      end

      def parse_manifest(manifest_path, plugin_dir)
        content = File.read(manifest_path)

        name = content[/name\s+["'](.+?)["']/, 1]
        version = content[/version\s+["'](.+?)["']/, 1] || "0.0.0"
        priority = content[/priority\s+(\d+)/, 1]&.to_i || 0

        return nil unless name

        PluginManifest.new(
          name: name,
          version: version,
          priority: priority,
          path: plugin_dir
        )
      end

      def load_plugin_routes!(root)
        loaded_plugins.each do |plugin|
          routes_file = plugin.path.join("config", "routes.rb")
          next unless routes_file.exist?

          # Routes are drawn in via the Rails router — see the initializer.
        end
      end

      def sync_build!(root)
        build_manager = Plugins::BuildManager.new(root: root)
        build_manager.sync!
      end
    end
  end
end
