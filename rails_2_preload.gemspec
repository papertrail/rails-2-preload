Gem::Specification.new do |spec|
  spec.name        = "rails_2_preload"
  spec.version     = "0.0.4.paperless"
  spec.date        = "2012-07-30"
  spec.summary     = "Preloads Rails 2 for testing with Spin"
  spec.description = %{The purpose of Rails2Preload is to optimize testing with Spin
 and Rails 2. It does this by splitting the Rails 2 initialization method
 (Rails::Initializer#process) into two phases: preload and postload.}
  spec.authors     = ["Todd Mazierski"]
  spec.email       = "todd@paperlesspost.com"
  spec.files       = ["lib/rails_2_preload.rb"]
  spec.homepage    = "https://github.com/paperlesspost/rails-2-preload"
end
