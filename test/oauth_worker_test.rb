require_relative "test_helper"

class OauthWorkerTest < Minitest::Test
  def test_worker_js_passes_node_syntax_check
    worker = "#{TEMPLATE_ROOT}/oauth-worker/src/worker.js"
    assert File.exist?(worker), "worker.js missing"
    output = `node --check #{worker} 2>&1`
    assert_equal 0, $?.exitstatus, "node --check failed: #{output}"
  end

  def test_wrangler_template_has_required_placeholders
    template = File.read("#{TEMPLATE_ROOT}/oauth-worker/wrangler.toml.template")
    assert_includes template, "__GITHUB_ORG_SLUG__"
    assert_includes template, "ALLOWED_ORIGINS"
    assert_includes template, "ALLOWED_REPOS"
  end

  def test_wrangler_template_documents_required_secrets
    template = File.read("#{TEMPLATE_ROOT}/oauth-worker/wrangler.toml.template")
    %w[OAUTH_GITHUB_CLIENT_ID OAUTH_GITHUB_CLIENT_SECRET WORKER_SECRET].each do |secret|
      assert_includes template, secret, "wrangler.toml.template should document #{secret}"
    end
  end
end
