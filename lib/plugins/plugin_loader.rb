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
        newly_cloned = clone_missing_plugins!(root)
        discover_plugins(root)
        load_plugin_routes!(root)
        sync_build!(root)
        sync_plugin_records!

        # Restart so the next boot registers the new plugin's migration paths
        # and picks up any new routes/autoload paths cleanly.
        schedule_restart!(root) if newly_cloned.any?
      end

      private

      # For each active Plugin record not installed locally:
      #   - if it has a github_url, clone it before boot
      #   - if still missing after clone (or no URL), mark as failed
      # Returns the list of successfully cloned plugin names.
      def clone_missing_plugins!(root)
        return [] unless defined?(Plugin) && Plugin.table_exists?

        newly_cloned = []

        Plugin.active.each do |plugin_record|
          next if plugin_record.installed_locally?

          if plugin_record.github_url.present?
            Rails.logger.info "[PluginLoader] Cloning missing plugin '#{plugin_record.name}' from #{plugin_record.github_url}"
            plugins_dir = root.join("storage", "plugins")
            FileUtils.mkdir_p(plugins_dir)

            cloned = system("git", "clone", "--depth", "1",
                            plugin_record.github_url,
                            plugin_record.local_path.to_s)

            newly_cloned << plugin_record.name if cloned && plugin_record.installed_locally?
          end

          unless plugin_record.installed_locally?
            Rails.logger.error "[PluginLoader] Plugin '#{plugin_record.name}' not found locally — marking as failed"
            plugin_record.update_columns(status: "failed")
          end
        end

        newly_cloned
      end

      def schedule_restart!(root)
        Rails.logger.info "[PluginLoader] New plugin(s) cloned — scheduling restart to register migration paths"
        FileUtils.touch(root.join("tmp", "restart.txt"))
      end

      # After loading, upsert Plugin records for each discovered plugin.
      def sync_plugin_records!
        return unless defined?(Plugin) && Plugin.table_exists?

        loaded_plugins.each do |manifest|
          commit_sha = read_commit_sha(manifest.path)
          Plugin.find_or_initialize_by(name: manifest.name).tap do |record|
            record.version = manifest.version
            record.commit_sha = commit_sha
            record.status = "active" if record.status == "failed" || record.new_record?
            record.save!
          end
        rescue => e
          Rails.logger.error "[PluginLoader] Failed to sync Plugin record for '#{manifest.name}': #{e.message}"
        end
      end

      def read_commit_sha(plugin_dir)
        git_dir = plugin_dir.join(".git")
        return nil unless git_dir.exist?

        sha = `git -C #{plugin_dir} rev-parse HEAD 2>/dev/null`.strip
        sha.empty? ? nil : sha
      end

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
