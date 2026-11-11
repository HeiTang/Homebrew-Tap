require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

class UpdateCasksTest < Minitest::Test
  SCRIPT = File.expand_path("../scripts/update-casks.rb", __dir__)
  BYTES = "synthetic installer bytes"
  SHA256 = Digest::SHA256.hexdigest(BYTES)

  def setup
    @dir = Dir.mktmpdir("cask-updater-test-")
    FileUtils.mkdir_p(["#{@dir}/Casks", "#{@dir}/bin"])
    @releases = {}
    @before = {}
    File.write("#{@dir}/bin/gh", <<~RUBY)
      #!#{RbConfig.ruby}
      require "json"
      data = JSON.parse(File.read("releases.json"))
      if ARGV[0] == "api"
        repo = ARGV[1].delete_prefix("repos/").delete_suffix("/releases/latest")
        abort "API unavailable" unless data.key?(repo)
        puts JSON.generate(data.fetch(repo))
      elsif ARGV[0, 2] == ["release", "download"]
        name = ARGV.fetch(ARGV.index("--pattern") + 1)
        dir = ARGV.fetch(ARGV.index("--dir") + 1)
        File.binwrite(File.join(dir, name), ENV.fetch("TEST_DOWNLOAD"))
      else
        abort "Unexpected gh arguments"
      end
    RUBY
    File.chmod(0755, "#{@dir}/bin/gh")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def add_app(token, repo, asset, prefix = "v")
    template = "https://github.com/#{repo}/releases/download/#{prefix}\#{version}/#{asset}"
    source = <<~CASK
      cask "#{token}" do
        version "1.0.0"
        sha256 "#{'b' * 64}"

        url "#{template}"
        name "#{token}"
        livecheck do
          url :url
          strategy :github_latest
        end
        app "#{token}.app"
      end
    CASK
    @before[token] = source
    File.write("#{@dir}/Casks/#{token}.rb", source)
    @releases[repo] = {
      "tag_name" => "#{prefix}1.1.0", "draft" => false, "prerelease" => false,
      "assets" => [{"name" => asset.gsub('#{version}', "1.1.0"),
                    "digest" => "sha256:#{SHA256}",
                    "browser_download_url" => template.gsub('#{version}', "1.1.0")}]
    }
  end

  def run_update(download = BYTES)
    File.write("#{@dir}/releases.json", JSON.generate(@releases))
    Open3.capture3({"PATH" => "#{@dir}/bin:#{ENV.fetch('PATH')}", "TEST_DOWNLOAD" => download},
                  RbConfig.ruby, SCRIPT, chdir: @dir)
  end

  def assert_unchanged
    @before.each { |token, source| assert_equal source, File.read("#{@dir}/Casks/#{token}.rb") }
  end

  def test_multiple_apps_including_versioned_asset_and_unprefixed_tag
    add_app("first", "Example/First", "First-arm64.dmg")
    add_app("second", "Another/Second", 'Second-#{version}.zip', "")
    stdout, stderr, status = run_update
    assert status.success?, stderr
    @before.each do |token, source|
      expected = source.sub('version "1.0.0"', 'version "1.1.0"').sub('b' * 64, SHA256)
      assert_equal expected, File.read("#{@dir}/Casks/#{token}.rb")
      assert_includes stdout, "#{token} 1.0.0 → 1.1.0"
    end
  end

  def test_same_and_older_versions_do_nothing
    add_app("first", "Example/First", "First.dmg")
    add_app("second", "Example/Second", "Second.zip")
    @releases["Example/First"]["tag_name"] = "v1.0.0"
    @releases["Example/Second"]["tag_name"] = "v0.9.0"
    stdout, stderr, status = run_update
    assert status.success?, stderr
    assert_empty stdout
    assert_unchanged
  end

  def test_invalid_second_app_leaves_both_casks_unchanged
    ["digest", "url", "missing", "duplicate", "prerelease", "draft", "tag", "api"].each do |failure|
      add_app("first", "Example/First", "First.dmg")
      add_app("second", "Example/Second", "Second.dmg")
      release = @releases["Example/Second"]
      case failure
      when "digest" then release["assets"][0]["digest"] = nil
      when "url" then release["assets"][0]["browser_download_url"] = "https://example.com/bad.dmg"
      when "missing" then release["assets"] = []
      when "duplicate" then release["assets"] *= 2
      when "prerelease" then release["prerelease"] = true
      when "draft" then release["draft"] = true
      when "tag" then release["tag_name"] = "v1.1.0\ninjected=true"
      when "api" then @releases.delete("Example/Second")
      end
      stdout, stderr, status = run_update
      refute status.success?, failure
      assert_empty stdout
      assert_includes stderr, "Casks/second.rb"
      assert_unchanged
    end
  end

  def test_only_newer_app_is_changed
    add_app("first", "Example/First", "First.dmg")
    add_app("second", "Example/Second", "Second.zip")
    @releases["Example/First"]["tag_name"] = "v1.0.0"
    stdout, stderr, status = run_update
    assert status.success?, stderr
    assert_equal @before["first"], File.read("#{@dir}/Casks/first.rb")
    refute_includes stdout, "first 1.0.0"
    assert_includes stdout, "second 1.0.0 → 1.1.0"
  end

  def test_corrupt_download_is_rejected
    add_app("first", "Example/First", "First.dmg")
    stdout, stderr, status = run_update("corrupt bytes")
    refute status.success?
    assert_empty stdout
    assert_includes stderr, "SHA-256 mismatch"
    assert_unchanged
  end

  def test_unsupported_cask_fails_without_changes
    add_app("first", "Example/First", "First.dmg")
    path = "#{@dir}/Casks/first.rb"
    @before["first"] = @before["first"].sub("https://github.com/", "https://example.com/")
    File.write(path, @before["first"])
    _, stderr, status = run_update
    refute status.success?
    assert_includes stderr, "Unsupported Cask"
    assert_unchanged
  end
end
