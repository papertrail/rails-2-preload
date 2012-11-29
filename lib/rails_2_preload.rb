require "benchmark"
require "pathname"

# The purpose of Rails2Preload is to optimize testing with Spin and Rails 2.
# It does this by splitting the Rails 2 initialization method
# (Rails::Initializer#process) into two phases: preload and postload. This
# gives us the capability of using Spin:
#
# * without having to reboot every time a class is modified
#
# * without having to disable class caching, which is enabled by default in
#   the Rails "test" environment - unfortunately, some testing tools have come
#   to rely on this (Capybara, for example)
#
class Rails2Preload

  PRELOAD_METHODS = [
    :check_ruby_version,
    :install_gem_spec_stubs,
    :set_load_path,
    :add_gem_load_paths,
    :require_frameworks,
    :set_autoload_paths,
    :add_plugin_load_paths,
    :load_environment,
    :preload_frameworks,
    :initialize_encoding,
    :initialize_database,
    :initialize_cache,
    :initialize_framework_caches,
    :initialize_logger,
    :initialize_framework_logging,
    :initialize_dependency_mechanism,
    :initialize_whiny_nils,
    :initialize_time_zone,
    :initialize_i18n,
    :initialize_framework_settings,
    :initialize_framework_views,
    :initialize_metal,
    :add_support_load_paths,
    :check_for_unbuilt_gems,
    :load_gems,
    :load_plugins,
    :add_gem_load_paths,
    :load_gems,
    :check_gem_dependencies,
    :load_application_initializers,
    :after_initialize,
    :initialize_database_middleware,
    :prepare_dispatcher,
    :initialize_routing,
    :load_observers
  ]

  POSTLOAD_METHODS = [
    :load_view_paths,
    :load_application_classes,
    :disable_dependency_loading
  ]

  class << self

    # If set to true, classes are loaded as a part of the preload phase. Best
    # for situations where the test author doesn't need to modify the Rails
    # code.
    attr_accessor :preload_classes
    alias :preload_classes? :preload_classes

    # Called from .spin.rb to add all hooks necessary to integrate
    # Rails2Preload.
    def add_spin_hooks
      Spin.hook(:before_preload) { Rails2Preload.prepare_rails }

      Spin.hook(:after_preload) do
        if Rails2Preload.preload_classes?
          # When classes are preloaded, empty the connection pool so forked
          # processes are forced to establish new connections. Otherwise, the
          # second time a test is run, an exception like this is raised:
          #   ActiveRecord::StatementInvalid PGError: no connection to the server
          ActiveRecord::Base.connection_pool.disconnect!
        end
      end

      Spin.hook(:after_fork) do
        # Create a new initializer instance, but reuse the configuration
        # already established by the preload phase.
        initializer = Rails::Initializer.new(Rails.configuration)
        initializer.postload
      end
    end

    # Called by the Rails patch to run the preload phase.
    def preload(initializer)
      preload_methods.each { |method| benchmark(initializer, method) }
    end

    # Called by the Rails patch to run the postload phase.
    def postload(initializer)
      postload_methods.each { |method| benchmark(initializer, method) }
    end

    # Called by the :before_preload Spin hook to prepare Rails.
    def prepare_rails
      # We need to boot Rails before adding methods to Rails::Initializer.
      # Otherwise, Rails.booted? returns true and Rails.boot! short-circuits.
      boot_rails
      apply_initializer_patch
    end

  private

    # This is the monkey-patch that splits the Rails 2 initialization process
    # (Rails::Initializer#process) into two phases, preload and postload.
    def apply_initializer_patch
      module_eval <<-RUBY , __FILE__, __LINE__ + 1
        module ::Rails
          class Initializer
            # The run method does support executing an arbitrary method (the
            # command parameter) to initialize Rails. However, my preference
            # is to not change anything (including environment.rb) in any way
            # to support Spin.
            def self.run(command = :preload, configuration = Configuration.new)
              yield configuration if block_given?
              initializer = new configuration
              initializer.send(command)
              initializer
            end

            # Runs the first half of the Rails initialization process.
            def preload
              Rails.configuration = configuration
              Rails2Preload.preload(self)
            end

            # Runs the second half of the Rails initialization process.
            def postload
              Rails2Preload.postload(self)
              Rails.initialized = true
            end
          end # Initializer
        end # Rails
      RUBY
    end

    # Returns all of the methods that should be run in the preload phase.
    def preload_methods
      if preload_classes?
        PRELOAD_METHODS << :load_application_classes
      else
        PRELOAD_METHODS
      end
    end

    # Returns all of the methods that should be run in the postload phase.
    def postload_methods
      if preload_classes?
        POSTLOAD_METHODS - [:load_application_classes]
      else
        POSTLOAD_METHODS
      end
    end

    def rails_root
      Bundler.root
    end

    def boot_rails
      require rails_root + "config" + "boot"
    end

    # Benchmarks a method sent to an object and outputs the result to the
    # console.
    def benchmark(object, method, *args)
      print "[Rails2Preload] #{method}"
      result = Benchmark.realtime { object.send(method, *args) }
      puts "#{"%0.3f" % result}s".rjust(40 - method.length)
    end

  end # self
end # Rails2Preload
