require "digest"
require "json"
require "open3"
require "rubygems/version"
require "tmpdir"

def command(*args)
  stdout, stderr, status = Open3.capture3(*args)
  raise "#{args.first(2).join(' ')} failed: #{stderr}" unless status.success?

  stdout
end

updates = []
paths = Dir.glob("Casks/*.rb").sort
abort "No Casks found" if paths.empty?

paths.each do |path|
  begin
    source = File.read(path)
    # shortcut: single-version GitHub Releases casks only; extend when an App needs another distribution format.
    %w[version sha256].each do |stanza|
      raise "Expected exactly one #{stanza} stanza" unless source.scan(/^[ \t]+#{stanza} /).length == 1
    end
    raise "Expected exactly one download URL" unless source.scan(/^  url /).length == 1
    current = source[/^  version "(\d+\.\d+\.\d+)"$/, 1]
    checksum = source[/^  sha256 "([0-9a-f]{64})"$/, 1]
    url = source.match(%r{^  url "(https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/releases/download/(v?)\#\{version\}/[^"]+)"$})
    raise "Unsupported Cask version, checksum or download URL" unless current && checksum && url

    template, repo, prefix = url.captures
    release = JSON.parse(command("gh", "api", "repos/#{repo}/releases/latest"))
    raise "Expected a stable published release" unless release["draft"] == false && release["prerelease"] == false
    tag = release.fetch("tag_name")
    raise "Unexpected release tag" unless tag.match?(/\A#{prefix}\d+\.\d+\.\d+\z/)
    version = tag.delete_prefix(prefix)
    next if Gem::Version.new(version) <= Gem::Version.new(current)

    download_url = template.gsub('#{version}', version)
    filename = download_url.split("/").last
    raise "Unsupported asset filename" unless filename.match?(/\A[A-Za-z0-9._+-]+\z/)
    assets = release.fetch("assets").select { |asset| asset["name"] == filename }
    raise "Expected exactly one #{filename} asset" unless assets.length == 1
    asset = assets.first
    raise "Unexpected download URL" unless asset["browser_download_url"] == download_url
    digest = asset.fetch("digest", "").to_s
    raise "Missing or invalid SHA-256" unless digest.match?(/\Asha256:[0-9a-f]{64}\z/)
    sha256 = digest.delete_prefix("sha256:")

    Dir.mktmpdir("cask-download-") do |dir|
      command("gh", "release", "download", tag, "--repo", repo, "--pattern", filename, "--dir", dir)
      raise "Downloaded asset SHA-256 mismatch" unless Digest::SHA256.file(File.join(dir, filename)).hexdigest == sha256
    end

    updated = source.sub(/^  version ".*"$/, "  version \"#{version}\"")
    updated = updated.sub(/^  sha256 ".*"$/, "  sha256 \"#{sha256}\"")
    updates << [path, updated, "- [#{File.basename(path, '.rb')} #{current} → #{version}](https://github.com/#{repo}/releases/tag/#{tag})"]
  rescue StandardError => e
    abort "#{path}: #{e.message}"
  end
end

# Verify every download before changing any Cask.
updates.each { |path, content, _| File.write(path, content) }
unless updates.empty?
  puts "更新以下 Cask 的版本與 SHA-256：\n\n"
  updates.each { |_, _, summary| puts summary }
  puts "\n已下載並核對所有安裝檔的 GitHub asset digest。請確認 Release 內容後手動合併。"
end
