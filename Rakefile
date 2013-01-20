require "bundler/setup"
Bundler.require(:rake)
Bundler.require(:test)

require "rdoc/task"
require "rake/testtask"

Rake::TestTask.new do |task|
  task.pattern = "test/*_test.rb"
  task.libs << "test"
end

Rake::RDocTask.new do |rd|
  rd.title = "Rails2Preload"
end

Gokdok::Dokker.new do |gd|
  gd.repo_url = "git@github.com:paperlesspost/rails-2-preload.git"
  gd.remote_path = "./"
end

desc "Run tests"
task :default => :test
