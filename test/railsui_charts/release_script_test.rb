# frozen_string_literal: true

require "test_helper"

class ReleaseScriptTest < Minitest::Test
  SCRIPT = File.expand_path("../../bin/release", __dir__)

  def source
    @source ||= File.read(SCRIPT)
  end

  def test_the_release_script_is_valid_bash
    assert system("bash", "-n", SCRIPT)
  end

  def test_it_refuses_to_release_anything_but_current_main
    guard = source.index('git branch --show-current)" != "main"')

    refute_nil guard
    assert_operator guard, :<, source.index("bin/changelog --check")
    assert_includes source, "git fetch origin main --tags"
    assert_includes source, 'git rev-parse origin/main'
  end

  def test_a_partial_registry_publish_can_be_resumed
    assert_includes source, "GEM_PUBLISHED=false"
    assert_includes source, "NPM_PUBLISHED=false"
    assert_includes source, 'if [ "$GEM_PUBLISHED" = true ]; then'
    assert_includes source, 'if [ "$NPM_PUBLISHED" = true ]; then'
  end

  def test_it_uses_the_pinned_yarn_runtime
    assert_includes source, "corepack yarn install --silent"
    assert_includes source, "corepack yarn build"
  end
end
