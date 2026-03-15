require 'open3'
require 'fileutils'
require 'securerandom'

class Accounts::AgentPluginBuilders::Build
  UPSTREAM_REPO = 'https://github.com/douglara/woofed-crm.git'
  WORK_DIR = Rails.root.join('tmp', 'agent_plugin_builders')

  def self.call(feature_request)
    new(feature_request).call
  end

  def initialize(feature_request)
    @feature_request = feature_request
    @plugin_slug = generate_plugin_slug
    @repo_name = "woofed-crm-plugin-#{@plugin_slug}"
    @work_path = nil
  end

  def call
    @feature_request.update(status: :processing)
    log("Starting AI plugin build...")

    validate_github_token!
    repo_url = create_plugin_repo
    @work_path = clone_upstream
    set_remote_origin(repo_url)
    push_base_branch
    run_opencode
    commit_and_push
    @feature_request.update(status: :completed, repo_url: repo_url)
    log("Plugin build completed! Repo: #{repo_url}")

    install_plugin_locally
    register_plugin_in_database(repo_url)
    trigger_app_restart

    { ok: @feature_request }
  rescue StandardError => e
    @feature_request.update(status: :failed, error_message: e.message)
    log("ERROR: #{e.message}")
    { error: e.message }
  ensure
    cleanup_work_dir
  end

  private

  def validate_github_token!
    unless github_token.present?
      raise "GITHUB_TOKEN environment variable is required. Set it with a personal access token that has 'repo' scope."
    end
  end

  def create_plugin_repo
    log("Creating plugin repository: #{@repo_name}...")

    conn = faraday_connection
    response = conn.post('/user/repos') do |req|
      req.body = { name: @repo_name, private: false }.to_json
    end

    unless [200, 201].include?(response.status)
      raise "Failed to create repository: #{response.status} - #{response.body}"
    end

    result = JSON.parse(response.body)
    repo_url = result['clone_url']
    log("Repository created: #{repo_url}")

    repo_url
  end

  def clone_upstream
    work_path = File.join(WORK_DIR, @repo_name)
    FileUtils.mkdir_p(File.dirname(work_path))

    log("Cloning woofed-crm (branch: plugins-test5)...")
    authenticated_url = UPSTREAM_REPO.sub('https://', "https://x-access-token:#{github_token}@")
    env = { 'GIT_TERMINAL_PROMPT' => '0' }
    run_command_arr(env, ['git', 'clone', '--branch', 'plugins-test5', authenticated_url, work_path])
    log("Clone complete.")

    work_path
  end

  def set_remote_origin(repo_url)
    authenticated_url = repo_url.sub('https://', "https://x-access-token:#{github_token}@")
    log("Setting origin to plugin repository...")
    run_git_command("remote set-url origin #{authenticated_url}")
  end

  def push_base_branch
    log("Pushing development base to build-feature...")
    run_git_command("push origin HEAD:build-feature")
    log("Base push complete.")
  end

  OPENCODE_TIMEOUT = 2.hours.to_i
  OPENCODE_MODEL = "opencode/big-pickle"

  def run_opencode
    log("Running OpenCode AI to build the plugin (model: #{OPENCODE_MODEL})...")
    log("Description: #{@feature_request.description}")

    prompt = build_plugin_prompt
    cmd = "opencode run --model #{OPENCODE_MODEL} #{Shellwords.escape(prompt)}"

    output = run_streaming_command(cmd, chdir: @work_path, timeout: OPENCODE_TIMEOUT)
    log("OpenCode finished.")
    log("Output: #{output.truncate(5000)}")
  end

  def build_plugin_prompt
    plugin_guide = Rails.root.join('docs/plugins.md').read

    <<~PROMPT
      Build a WoofedCRM plugin that implements the following feature:

      #{@feature_request.description}

      Plugin name: #{@plugin_slug}
      Plugin folder: storage/plugins/#{@plugin_slug}/

      ## How Plugins works (follow this exactly):
      #{plugin_guide}

      Requirements:
      - Create all plugin files directly inside storage/plugins/#{@plugin_slug}/
      - Create storage/plugins/#{@plugin_slug}/plugin.rb with manifest (name: "#{@plugin_slug}", version: "1.0.0")
      - Do NOT modify any files inside app/ — all modifications must go through the FilePatch DSL
      - For each existing app/ file that needs to be extended: create a FilePatch file at the same relative path inside storage/plugins/#{@plugin_slug}/app/
      - For each new file the plugin needs: create it inside storage/plugins/#{@plugin_slug}/app/ at the appropriate relative path
      - Move any ActiveRecord macros (has_many, belongs_to, validates, scope) into ActiveSupport::Concern modules in new files inside the plugin
      - Create a full test suite under storage/plugins/#{@plugin_slug}/spec/
      - Add routes to storage/plugins/#{@plugin_slug}/config/routes.rb if needed — NEVER re-define routes already present in the main app; only add new plugin-specific routes
      - Add migrations to storage/plugins/#{@plugin_slug}/db/migrate/ if needed

    PROMPT
  end

  def commit_and_push
    log("Committing plugin files...")
    run_git_command("add -A")

    manifest = File.join(@work_path, "storage", "plugins", @plugin_slug, "plugin.rb")
    unless File.exist?(manifest)
      raise "OpenCode did not create plugin.rb in storage/plugins/#{@plugin_slug}/ — plugin build failed"
    end

    status_output = run_git_command("status --porcelain")
    if status_output.strip.empty?
      raise "OpenCode did not produce any changes"
    end

    log("Plugin files created: #{Dir[File.join(@work_path, "storage", "plugins", @plugin_slug, "**", "*")].count} file(s)")

    commit_message = "feat: add #{@plugin_slug} plugin"
    run_git_command("commit -m #{Shellwords.escape(commit_message)}")

    log("Pushing to origin build-feature...")
    run_git_command("push origin HEAD:build-feature")
    log("Push complete.")
  end

  def run_command_arr(env, args, chdir: nil)
    opts = chdir ? { chdir: chdir } : {}
    stdout, stderr, status = Open3.capture3(env, *args, **opts)
    unless status.success?
      raise "Command failed: #{args.join(' ')}\nstderr: #{stderr}\nstdout: #{stdout}"
    end
    stdout
  end

  def run_git_command(git_args_str)
    env = { 'GIT_TERMINAL_PROMPT' => '0' }
    args = ['git'] + git_args_str.shellsplit
    run_command_arr(env, args, chdir: @work_path)
  end

  def run_streaming_command(cmd, chdir:, timeout: OPENCODE_TIMEOUT)
    output = +"" # UTF-8 mutable string
    deadline = Time.current + timeout

    Open3.popen3(cmd, chdir: chdir) do |_stdin, stdout, stderr, wait_thread|
      _stdin.close
      stdout.binmode
      stderr.binmode

      streams = [stdout, stderr]
      until streams.empty?
        remaining = deadline - Time.current
        if remaining <= 0
          Process.kill('TERM', wait_thread.pid)
          raise "Command timed out after #{timeout} seconds: #{cmd}"
        end

        ready = IO.select(streams, nil, nil, [remaining, 30].min)
        next unless ready

        ready[0].each do |io|
          begin
            raw = io.read_nonblock(8192)
            chunk = raw.encode("UTF-8", "binary", invalid: :replace, undef: :replace)
            output << chunk
            log(chunk.strip) if chunk.strip.present?
          rescue EOFError
            streams.delete(io)
          end
        end
      end

      status = wait_thread.value
      unless status.success?
        raise "Command failed: #{cmd}\noutput: #{output.last(2000)}"
      end
    end

    output
  end

  def install_plugin_locally
    plugin_source = File.join(@work_path, "storage", "plugins", @plugin_slug)
    plugin_dest = Rails.root.join("storage", "plugins", @plugin_slug)

    unless File.directory?(plugin_source)
      raise "Plugin source directory not found at #{plugin_source}"
    end

    manifest = File.join(plugin_source, "plugin.rb")
    unless File.exist?(manifest)
      raise "plugin.rb not found in #{plugin_source} — OpenCode did not generate a valid plugin"
    end

    # Sanity-check: a plugin must NOT look like a full Rails app
    rails_indicators = %w[Gemfile config.ru bin/rails app/assets/config/manifest.js]
    rails_indicators.each do |indicator|
      if File.exist?(File.join(plugin_source, indicator))
        raise "Plugin directory contains '#{indicator}' — OpenCode generated a full Rails app instead of a plugin. Aborting."
      end
    end

    files = Dir[File.join(plugin_source, "**", "*")].reject { |f| File.directory?(f) }
    log("Installing #{files.size} plugin file(s) from work directory...")

    FileUtils.mkdir_p(plugin_dest.dirname)
    FileUtils.rm_rf(plugin_dest)
    FileUtils.cp_r(plugin_source, plugin_dest.to_s)

    installed = Dir[File.join(plugin_dest, "**", "*")].reject { |f| File.directory?(f) }
    raise "Plugin installation failed — destination is empty after copy" if installed.empty?

    log("Plugin installed to #{plugin_dest} (#{installed.size} file(s))")
  end

  def register_plugin_in_database(repo_url)
    plugin = Plugin.find_or_initialize_by(name: @plugin_slug)
    plugin.github_url = repo_url
    plugin.status = "active"
    plugin.save!
    log("Plugin registered in database (id=#{plugin.id}).")
  end

  def trigger_app_restart
    FileUtils.touch(Rails.root.join("tmp", "restart.txt"))
    log("App restart triggered. Plugin will be active after boot.")
  end

  def cleanup_work_dir
    if @work_path && File.directory?(@work_path)
      FileUtils.rm_rf(@work_path)
      log("Cleaned up work directory.")
    end
  end

  def generate_plugin_slug
    @feature_request.name
      .downcase
      .gsub(/[^a-z0-9\s]/, '')
      .split
      .join('-')
  end

  def github_token
    ENV.fetch('GITHUB_TOKEN', nil)
  end

  def faraday_connection
    Faraday.new(url: 'https://api.github.com') do |f|
      f.headers['Authorization'] = "Bearer #{github_token}"
      f.headers['Accept'] = 'application/vnd.github+json'
      f.headers['Content-Type'] = 'application/json'
      f.headers['X-GitHub-Api-Version'] = '2022-11-28'
      f.adapter Faraday.default_adapter
    end
  end

  def log(message)
    @feature_request.append_log(message)
    Rails.logger.info("[AgentPluginBuilders::Build] #{message}")
  end
end
