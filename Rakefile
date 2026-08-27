# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new("test:ruby") do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

# No test-runner dependency: `node --test` is built in, and the only thing it
# was missing was a way to satisfy the two bare imports the controllers make.
# test/javascript/stubs.mjs does that with Node's own module hooks, which need
# Node 22.15 or newer.
#
# Skipped rather than failed when Node is absent, so a Ruby-only contributor
# can still run the suite.
desc "Run the JavaScript tests"
task "test:js" do
  unless system("node --version > /dev/null 2>&1")
    warn "Skipping JavaScript tests: node is not installed"
    next
  end

  abort "JavaScript tests failed" unless system(
    "node --import ./test/javascript/stubs.mjs --test 'test/javascript/*.test.mjs'"
  )
end

desc "Run every test"
task test: ["test:ruby", "test:js"]

task default: :test
