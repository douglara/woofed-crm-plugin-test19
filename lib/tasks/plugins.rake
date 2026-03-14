# frozen_string_literal: true

namespace :plugins do
  desc "Install a plugin from a public GitHub repository URL"
  task :install, [:url] => :environment do |_t, args|
    url = args[:url]
    abort "Usage: rails plugins:install[https://github.com/user/repo]" if url.blank?

    # Validate URL format (only allow GitHub HTTPS URLs)
    unless url.match?(%r{\Ahttps://github\.com/[\w.\-]+/[\w.\-]+(?:\.git)?\z})
      abort "Error: Only public GitHub HTTPS URLs are supported (https://github.com/user/repo)"
    end

    # Extract plugin name from URL
    plugin_name = File.basename(url, ".git")
    plugins_dir = Rails.root.join("storage", "plugins")
    plugin_path = plugins_dir.join(plugin_name)

    if plugin_path.exist?
      abort "Error: Plugin '#{plugin_name}' is already installed at #{plugin_path}"
    end

    puts "[plugins:install] Cloning #{url} into storage/plugins/#{plugin_name}..."
    FileUtils.mkdir_p(plugins_dir)
    unless system("git", "clone", "--depth", "1", url, plugin_path.to_s)
      abort "Error: git clone failed. Check the URL and try again."
    end

    # Validate that it's a valid plugin
    manifest = plugin_path.join("plugin.rb")
    unless manifest.exist?
      FileUtils.rm_rf(plugin_path)
      abort "Error: Repository does not contain a plugin.rb manifest. Removed."
    end

    puts "[plugins:install] Plugin '#{plugin_name}' cloned successfully."
    puts "[plugins:install] Running boot to activate plugin..."
    Rake::Task["plugins:boot"].invoke

    puts "[plugins:install] Restarting application..."
    FileUtils.touch(Rails.root.join("tmp", "restart.txt"))

    puts "[plugins:install] Done! Plugin '#{plugin_name}' is now installed and active."
  end

  desc "Uninstall a plugin by name"
  task :uninstall, [:name] => :environment do |_t, args|
    name = args[:name]
    abort "Usage: rails plugins:uninstall[plugin_name]" if name.blank?

    plugin_path = Rails.root.join("storage", "plugins", name)
    unless plugin_path.exist?
      abort "Error: Plugin '#{name}' not found in storage/plugins/"
    end

    puts "[plugins:uninstall] Removing plugin '#{name}'..."
    FileUtils.rm_rf(plugin_path)

    puts "[plugins:uninstall] Rebuilding without plugin..."
    Rake::Task["plugins:boot"].invoke

    puts "[plugins:uninstall] Restarting application..."
    FileUtils.touch(Rails.root.join("tmp", "restart.txt"))

    puts "[plugins:uninstall] Done! Plugin '#{name}' has been removed."
  end

  desc "Full plugin boot: rebuild, migrate, and compile assets"
  task boot: :environment do
    puts "[plugins:boot] Rebuilding storage/build/..."
    manager = Plugins::BuildManager.new
    manager.rebuild!
    files = manager.status
    puts "[plugins:boot] Build complete. #{files.size} file(s) in storage/build/"

    puts "[plugins:boot] Running db:prepare (create + migrate)..."
    Rake::Task["db:prepare"].invoke

    js_patched = files.any? { |f| f.match?(/\.(js|jsx|ts|tsx)$/) }
    css_patched = files.any? { |f| f.end_with?(".css") }

    if js_patched || css_patched
      puts "[plugins:boot] Installing JS dependencies (yarn install)..."
      system("yarn install --frozen-lockfile 2>/dev/null || yarn install") || puts("[plugins:boot] Warning: yarn install failed")

      if Rails.env.production?
        puts "[plugins:boot] Compiling assets for production..."
        Rake::Task["assets:precompile"].invoke
      else
        puts "[plugins:boot] Development mode — Vite dev server handles assets."
      end
    else
      puts "[plugins:boot] No JS/CSS plugin files, skipping asset steps."
    end

    puts "[plugins:boot] Done."
  end

  desc "Wipe and recreate storage/build/ from scratch"
  task rebuild: :environment do
    puts "Rebuilding storage/build/..."
    manager = Plugins::BuildManager.new
    manager.rebuild!
    puts "Done. Files in storage/build/:"
    manager.status.each { |f| puts "  #{f}" }
  end

  desc "Print composed file after patches (e.g. rails plugins:preview[app/models/contact.rb])"
  task :preview, [:target] => :environment do |_t, args|
    target = args[:target]
    abort "Usage: rails plugins:preview[app/models/contact.rb]" unless target

    manager = Plugins::BuildManager.new
    result = manager.preview(target)

    if result
      puts result
    else
      abort "File not found: #{target}"
    end
  end

  desc "List all files currently in storage/build/"
  task status: :environment do
    manager = Plugins::BuildManager.new
    files = manager.status

    if files.empty?
      puts "storage/build/ is empty or does not exist."
    else
      puts "Files in storage/build/ (#{files.size}):"
      files.each { |f| puts "  #{f}" }
    end
  end
end
