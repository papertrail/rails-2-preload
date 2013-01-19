# Rails2Preload

## Description

The purpose of Rails2Preload is to optimize testing with [Spin](https://github.com/jstorimer/spin/) and Rails 2. It does this by splitting the Rails 2 initialization method ([`Rails::Initializer#process`](https://github.com/rails/rails/blob/2-3-stable/railties/lib/initializer.rb#L126)) into two phases: *preload* and *postload*. This gives us the capability of using Spin:

* without having to reboot Rails every time a class is modified
* without having to disable class caching

## Installation

1. In your `Gemfile`, add:

    ```ruby
    gem "rails_2_preload", "~> 0.1"
    ```

2. In your [`.spin.rb`](https://github.com/jstorimer/spin/blob/7e3acfbff6645f5c9fdc7be3fb2da4c87233ebb0/lib/spin/hooks.rb#L15-L18) file, add:

    ```ruby
    require "rails_2_preload"
    Rails2Preload.add_spin_hooks
    ```

## Usage

1. Start the Spin server

        $ spin serve --preload=config/environment.rb --load-path=test

2. Push a test to Spin

        $ spin push test/unit/your_test.rb

## Advanced

### preload_until

By default, Rails2Preload preloads until the application classes (i.e. models) are loaded. This is optimal for unit testing. This can be changed, however, with the `preload_until` method. For example, for functional tests, we may want to preload everything up until the views:

```ruby
Rails2Preload.preload_until(:load_view_paths)
```

To take advantage of this feature, create a Ruby script and preload it with Spin (instead of `config/environment.rb`):

    $ spin serve --preload=test/functional/preload.rb --load-path=test

```ruby
# test/functional/preload.rb
Rails2Preload.preload_until(:load_view_paths)
Rails2Preload.initialize_rails
```
