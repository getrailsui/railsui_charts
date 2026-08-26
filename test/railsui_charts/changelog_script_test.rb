# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "open3"

# bin/changelog is the step that came apart twice, so it is the one part of the
# release that should not be taken on trust.
class ChangelogScriptTest < Minitest::Test
  SCRIPT = File.expand_path("../../bin/changelog", __dir__)
  BASE = "https://github.com/getrailsui/railsui_charts"

  FULL = <<~MD
    # Changelog

    ## [Unreleased]

    ### Fixed

    - Something that was broken is no longer broken.

    ## [0.2.2]

    ### Added

    - The thing 0.2.2 added.

    [Unreleased]: #{BASE}/compare/v0.2.2...HEAD
    [0.2.2]: #{BASE}/compare/v0.2.1...v0.2.2
  MD

  EMPTY = <<~MD
    # Changelog

    ## [Unreleased]

    ## [0.2.2]

    - The thing 0.2.2 added.

    [Unreleased]: #{BASE}/compare/v0.2.2...HEAD
  MD

  def run_script(contents, *args)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "CHANGELOG.md")
      File.write(path, contents)
      out, err, status = Open3.capture3(SCRIPT, *args, "--file", path)
      yield(File.read(path), out, err, status)
    end
  end

  def test_it_promotes_unreleased_to_the_version
    run_script(FULL, "0.2.3") do |after, _out, _err, status|
      assert_predicate status, :success?
      assert_includes after, "## [0.2.3]"
      assert_includes after, "- Something that was broken is no longer broken."
    end
  end

  # The entries have to end up under the number, not left behind under
  # [Unreleased] where the next release would sweep them up as its own. That is
  # the exact failure this replaces.
  def test_the_entries_move_under_the_number
    run_script(FULL, "0.2.3") do |after, _out, _err, _status|
      unreleased = after[/^## \[Unreleased\]\n(.*?)(?=^## \[)/m, 1]
      promoted = after[/^## \[0\.2\.3\]\n(.*?)(?=^## \[)/m, 1]

      assert_empty unreleased.strip, "[Unreleased] should be left empty for the next cycle"
      assert_includes promoted, "no longer broken"
    end
  end

  def test_it_leaves_an_empty_unreleased_heading_for_next_time
    run_script(FULL, "0.2.3") do |after, _out, _err, _status|
      assert_includes after, "## [Unreleased]"
      assert_operator after.index("## [Unreleased]"), :<, after.index("## [0.2.3]")
    end
  end

  def test_it_moves_the_compare_links
    run_script(FULL, "0.2.3") do |after, _out, _err, _status|
      assert_includes after, "[Unreleased]: #{BASE}/compare/v0.2.3...HEAD"
      assert_includes after, "[0.2.3]: #{BASE}/compare/v0.2.2...v0.2.3"
      assert_includes after, "[0.2.2]: #{BASE}/compare/v0.2.1...v0.2.2"
    end
  end

  # The guard. Releasing with nothing written is how work ships undocumented,
  # which is the thing all of this exists to stop.
  def test_it_refuses_an_empty_unreleased
    run_script(EMPTY, "0.2.3") do |after, _out, err, status|
      refute_predicate status, :success?
      assert_match(/\[Unreleased\] is empty/, err)
      assert_equal EMPTY, after, "a refused release must not touch the file"
    end
  end

  def test_check_writes_nothing
    run_script(FULL, "--check", "0.2.3") do |after, out, _err, status|
      assert_predicate status, :success?
      assert_equal FULL, after
      assert_includes out, "no longer broken"
    end
  end

  # Someone who wrote the heading by hand meant it. Rewriting it would be the
  # script guessing at intent it does not have.
  def test_it_leaves_a_hand_written_section_alone
    hand = FULL.sub("## [Unreleased]\n", "## [Unreleased]\n\n## [0.2.3]\n")

    run_script(hand, "0.2.3") do |after, out, _err, status|
      assert_predicate status, :success?
      assert_equal hand, after
      assert_includes out, "no longer broken"
    end
  end

  def test_it_refuses_a_hand_written_section_that_is_empty
    hand = FULL.sub("## [Unreleased]\n\n### Fixed\n\n- Something that was broken is no longer broken.\n",
                    "## [Unreleased]\n\n## [0.2.3]\n")

    run_script(hand, "0.2.3") do |_after, _out, err, status|
      refute_predicate status, :success?
      assert_match(/is empty/, err)
    end
  end

  def test_it_refuses_a_changelog_with_no_unreleased_section
    run_script("# Changelog\n\n## [0.2.2]\n\n- A thing.\n", "0.2.3") do |_after, _out, err, status|
      refute_predicate status, :success?
      assert_match(/no \[Unreleased\] section/, err)
    end
  end
end
