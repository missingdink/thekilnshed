require_relative "test_helper"
require "yaml"

class TemplateSyncTest < Minitest::Test
  def setup
    @tmpdir   = Dir.mktmpdir("template-sync-test-")
    @upstream = "#{@tmpdir}/upstream"
    @site     = "#{@tmpdir}/site"
    FileUtils.mkdir_p("#{@upstream}/.github/workflows")
    FileUtils.mkdir_p("#{@site}/.github/workflows")
    FileUtils.mkdir_p("#{@site}/src")

    File.write("#{@upstream}/.github/workflows/deploy-site.yml", "new contents\n")
    File.write("#{@site}/.github/workflows/deploy-site.yml", "old contents\n")
    File.write("#{@site}/src/index.erb", "site-owned\n")

    File.write("#{@site}/.template-sync.yml", <<~YAML)
      upstream:
        repo: local-fixture
        ref: main
      tracked:
        - .github/workflows/deploy-site.yml
      excluded:
        - src/**
      last_synced:
        sha: ""
        date: ""
    YAML

    FileUtils.cp("#{TEMPLATE_ROOT}/bin/template-sync", "#{@site}/bin-template-sync")
    FileUtils.chmod(0755, "#{@site}/bin-template-sync")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def run_sync(args = [])
    Dir.chdir(@site) do
      IO.popen(["./bin-template-sync", "--upstream-path", @upstream, *args], err: [:child, :out], &:read)
    end
  end

  def test_tracked_file_is_overwritten_with_upstream_contents
    run_sync(["--dry-run=false", "--no-commit"])
    assert_equal "new contents\n", File.read("#{@site}/.github/workflows/deploy-site.yml")
  end

  def test_excluded_file_is_not_touched
    run_sync(["--dry-run=false", "--no-commit"])
    assert_equal "site-owned\n", File.read("#{@site}/src/index.erb")
  end

  def test_dry_run_does_not_modify_files
    run_sync(["--dry-run=true"])
    assert_equal "old contents\n", File.read("#{@site}/.github/workflows/deploy-site.yml")
  end

  def test_no_op_when_tracked_files_match
    File.write("#{@site}/.github/workflows/deploy-site.yml", "new contents\n")
    out = run_sync(["--dry-run=false", "--no-commit"])
    assert_match(/no changes/i, out)
  end
end
