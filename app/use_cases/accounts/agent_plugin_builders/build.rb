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
    @branch_name = generate_branch_name
    @work_path = nil
  end

  def call
    @feature_request.update(status: :processing, branch_name: @branch_name)
    log("Starting AI feature build...")

    validate_github_token!
    fork_repo_url = fork_repository
    @work_path = clone_fork(fork_repo_url)
    create_branch
    run_opencode
    commit_and_push
    @feature_request.update(status: :completed, repo_url: fork_repo_url)
    log("Feature build completed successfully! Repo: #{fork_repo_url}, Branch: #{@branch_name}")

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
      raise "GITHUB_TOKEN environment variable is required. Set it with a personal access token that has 'repo' and 'delete_repo' scopes."
    end
  end

  def fork_repository
    log("Forking upstream repository...")

    conn = faraday_connection
    response = conn.post('/repos/douglara/woofed-crm/forks') do |req|
      req.body = { name: fork_repo_name, default_branch_only: false }.to_json
    end

    unless [200, 202].include?(response.status)
      raise "Failed to fork repository: #{response.status} - #{response.body}"
    end

    result = JSON.parse(response.body)
    fork_url = result['clone_url']
    log("Fork created: #{fork_url}")

    wait_for_fork(result['full_name'])

    fork_url
  end

  def wait_for_fork(full_name)
    log("Waiting for fork to be ready...")
    conn = faraday_connection

    10.times do
      sleep 3
      response = conn.get("/repos/#{full_name}")
      if response.status == 200
        log("Fork is ready.")
        return
      end
    end

    raise "Fork did not become ready in time"
  end

  def clone_fork(fork_url)
    work_path = File.join(WORK_DIR, @branch_name)
    FileUtils.mkdir_p(work_path)

    log("Cloning fork...")
    run_command("git -c http.extraHeader=#{Shellwords.escape("Authorization: Bearer #{github_token}")} clone #{Shellwords.escape(fork_url)} #{Shellwords.escape(work_path)}")
    log("Clone complete.")

    work_path
  end

  def create_branch
    log("Creating branch: #{@branch_name}")
    run_git_command("checkout -b #{Shellwords.escape(@branch_name)}")
  end

  OPENCODE_TIMEOUT = 2.hours.to_i

  def run_opencode
    log("Running OpenCode AI to develop the feature...")
    log("Description: #{@feature_request.description}")

    escaped_description = Shellwords.escape(@feature_request.description)
    cmd = "opencode run #{escaped_description}"

    output = run_streaming_command(cmd, chdir: @work_path, timeout: OPENCODE_TIMEOUT)
    log("OpenCode finished.")
    log("Output: #{output.truncate(5000)}")
  end

  def commit_and_push
    log("Committing changes...")

    run_git_command("add -A")

    status_output = run_git_command("status --porcelain")
    if status_output.strip.empty?
      raise "OpenCode did not produce any changes"
    end

    commit_message = "feat: #{@feature_request.description.truncate(72)}"
    run_git_command("commit -m #{Shellwords.escape(commit_message)}")

    log("Pushing to remote branch #{@branch_name}...")
    run_git_command("push origin #{Shellwords.escape(@branch_name)}")
    log("Push complete.")
  end

  def run_command(cmd)
    stdout, stderr, status = Open3.capture3(cmd)
    unless status.success?
      raise "Command failed: #{cmd}\nstderr: #{stderr}\nstdout: #{stdout}"
    end
    stdout
  end

  def run_git_command(git_args)
    cmd = "git -c http.extraHeader=#{Shellwords.escape("Authorization: Bearer #{github_token}")} #{git_args}"
    stdout, stderr, status = Open3.capture3(cmd, chdir: @work_path)
    unless status.success?
      raise "Git command failed: git #{git_args}\nstderr: #{stderr}\nstdout: #{stdout}"
    end
    stdout
  end

  def run_streaming_command(cmd, chdir:, timeout: OPENCODE_TIMEOUT)
    output = +""
    deadline = Time.current + timeout

    Open3.popen3(cmd, chdir: chdir) do |_stdin, stdout, stderr, wait_thread|
      _stdin.close

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
            chunk = io.read_nonblock(8192)
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

  def cleanup_work_dir
    if @work_path && File.directory?(@work_path)
      FileUtils.rm_rf(@work_path)
      log("Cleaned up work directory.")
    end
  end

  def generate_branch_name
    slug = @feature_request.description
      .downcase
      .gsub(/[^a-z0-9\s]/, '')
      .split
      .first(5)
      .join('-')
    "ai-feature/#{slug}-#{SecureRandom.hex(4)}"
  end

  def fork_repo_name
    "woofed-crm-ai-#{SecureRandom.hex(4)}"
  end

  def github_token
    ENV.fetch('GITHUB_TOKEN', nil)
  end

  def github_username
    @github_username ||= begin
      conn = faraday_connection
      response = conn.get('/user')
      raise "Failed to get GitHub user: #{response.status}" unless response.status == 200
      JSON.parse(response.body)['login']
    end
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
