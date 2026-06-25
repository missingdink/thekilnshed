require_relative "test_helper"

class InitSiteTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("init-site-test-")
    File.write("#{@tmpdir}/sample.yml", <<~YAML)
      title: "__SITE_NAME__"
      url: "__SITE_URL__"
      repo: "__GITHUB_REPO__"
    YAML
    FileUtils.mkdir_p("#{@tmpdir}/bin")
    FileUtils.cp("#{TEMPLATE_ROOT}/bin/init-site", "#{@tmpdir}/bin/init-site")
    FileUtils.chmod(0755, "#{@tmpdir}/bin/init-site")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def run_init(answers, args = [])
    input = answers.join("\n") + "\n"
    Dir.chdir(@tmpdir) do
      IO.popen(["bin/init-site", *args, err: [:child, :out]], "r+") do |io|
        io.write(input)
        io.close_write
        io.read
      end
    end
  end

  def test_substitutes_all_placeholders_in_non_interactive_mode
    output = run_init([], ["--non-interactive", "--defaults"])
    content = File.read("#{@tmpdir}/sample.yml")
    refute_includes content, "__SITE_NAME__"
    refute_includes content, "__SITE_URL__"
    refute_includes content, "__GITHUB_REPO__"
    assert_match(/Example Site/, content)
  end

  def test_refuses_to_run_twice_without_force
    run_init([], ["--non-interactive", "--defaults"])
    out = run_init([], ["--non-interactive", "--defaults"])
    assert_match(/already been run/i, out + IO.read("#{@tmpdir}/sample.yml"))
    Dir.chdir(@tmpdir) do
      system("bin/init-site --non-interactive --defaults")
      assert_equal 2, $?.exitstatus
    end
  end

  def test_force_reruns_substitution
    run_init([], ["--non-interactive", "--defaults"])
    File.write("#{@tmpdir}/sample.yml", File.read("#{@tmpdir}/sample.yml") + "\nextra: __SITE_NAME__\n")
    out = run_init([], ["--non-interactive", "--defaults", "--force"])
    content = File.read("#{@tmpdir}/sample.yml")
    refute_includes content, "__SITE_NAME__"
  end

  def test_skips_test_and_docs_directories
    FileUtils.mkdir_p("#{@tmpdir}/test")
    FileUtils.mkdir_p("#{@tmpdir}/docs")
    File.write("#{@tmpdir}/test/fixture.yml", "title: \"__SITE_NAME__\"\n")
    File.write("#{@tmpdir}/docs/runbook.md", "See __SITE_NAME__ deploy guide.\n")
    run_init([], ["--non-interactive", "--defaults"])
    assert_includes File.read("#{@tmpdir}/test/fixture.yml"), "__SITE_NAME__"
    assert_includes File.read("#{@tmpdir}/docs/runbook.md"), "__SITE_NAME__"
  end

  def test_skips_entire_bin_directory
    File.write("#{@tmpdir}/bin/other-script", "#!/usr/bin/env ruby\n.gsub(\"__SITE_NAME__\", x)\n")
    File.write("#{@tmpdir}/bin/some-tool", "# References __SITE_URL__ in a comment\n")
    run_init([], ["--non-interactive", "--defaults"])
    assert_includes File.read("#{@tmpdir}/bin/other-script"), "__SITE_NAME__"
    assert_includes File.read("#{@tmpdir}/bin/some-tool"), "__SITE_URL__"
  end

  def test_writes_template_initialized_marker
    refute File.exist?("#{@tmpdir}/.template-initialized")
    run_init([], ["--non-interactive", "--defaults"])
    assert File.exist?("#{@tmpdir}/.template-initialized"), ".template-initialized marker missing"
    content = File.read("#{@tmpdir}/.template-initialized")
    assert_match(/\A\d{4}-\d{2}-\d{2}\n?\z/, content, "marker should contain ISO date")
  end
end
