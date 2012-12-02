# Rails2Preload

## Description

The purpose of Rails2Preload is to optimize testing with [Spin](https://github.com/jstorimer/spin/) and Rails 2. It does this by splitting the Rails 2 initialization method ([`Rails::Initializer#process`](https://github.com/rails/rails/blob/2-3-stable/railties/lib/initializer.rb#L126)) into two phases: preload and postload. This gives us the capability of using Spin:

* without having to reboot Rails every time a class is modified
* without having to disable class caching, which is enabled by default in the Rails "test" environment &mdash; unfortunately, some testing tools have come to rely on this ([Capybara](https://github.com/jnicklas/capybara/), for example)

## Installation

1. In your `Gemfile`, add:

    ```ruby
    gem "rails_2_preload"
    ```

2. In your `.spin.rb` file, add:

    ```ruby
    require "rails_2_preload"
    Rails2Preload.add_spin_hooks
    ```

## Usage

1. Start the Spin server

        $ spin serve --preload=config/environment.rb --load-path=test

2. Push a test to Spin

        $ spin push test/unit/your_test.rb
