require "benchmark"
require "pathname"

# The purpose of Rails2Preload is to optimize testing with Spin and Rails 2.
# It does this by splitting the Rails 2 initialization method
# (Rails::Initializer#process) into two phases: preload and postload. This
# gives us the capability of using Spin:
#
# * without having to reboot Rails every time a class is modified
#
# * without having to disable class caching
#
module Rails2Preload
  # All of the methods of the Rails initialization process, in order.
  METHODS = [
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
    :load_observers,
    :load_view_paths,
    :load_application_classes,
    :disable_dependency_loading
  ]

  class << self
    # The methods run in the preload phase.
    attr_reader :preload_methods
    # The methods run in the postload phase.
    attr_reader :postload_methods
  end

  # Given a method name, the methods of the Rails initialization process are
  # split into two groups, preload and postload.
  def self.preload_until(method)
    index = METHODS.index(method)
    raise(ArgumentError, method) if index.nil?

    @preload_methods, @postload_methods = METHODS[0..index - 1], METHODS[index..-1]
  end

  # By default, we'll preload until the application classes (i.e. models) are
  # loaded. This is optimal for unit testing.
  self.preload_until(:load_application_classes)

  # Called from .spin.rb to add all hooks necessary to integrate
  # Rails2Preload.
  def self.add_spin_hooks
    Spin.hook(:before_preload) { Rails2Preload.prepare_rails }

    Spin.hook(:after_preload) do
      if Rails2Preload.preload_methods.include? :load_application_classes
        # If classes are preloaded, empty the connection pool so forked
        # processes are forced to establish new connections. Otherwise, the
        # second time a test is run, an exception like this is raised:
        #   ActiveRecord::StatementInvalid PGError: no connection to the server
        ActiveRecord::Base.connection_pool.disconnect!
      end
    end

    Spin.hook(:after_fork) do
      # Create a new initializer instance, but reuse the configuration already
      # established by the preload phase.
      initializer = Rails::Initializer.new(Rails.configuration)
      initializer.postload
    end
  end

  # Called by the Rails patch to run the preload phase.
  def self.preload(initializer)
    preload_methods.each { |method| benchmark(initializer, method) }
  end

  # Called by the Rails patch to run the postload phase.
  def self.postload(initializer)
    postload_methods.each { |method| benchmark(initializer, method) }
  end

  # Called by the :before_preload Spin hook to prepare Rails.
  def self.prepare_rails
    # We need to boot Rails before adding methods to Rails::Initializer.
    # Otherwise, Rails.booted? returns true and Rails.boot! short-circuits.
    boot_rails
    apply_initializer_patch
  end

private

  # This is the monkey-patch that splits the Rails 2 initialization process
  # (Rails::Initializer#process) into two phases, preload and postload.
  def self.apply_initializer_patch
    module_eval <<-RUBY , __FILE__, __LINE__ + 1
      module ::Rails
        class Initializer
          # The run method *does* support calling an arbitrary method (the
          # command parameter) to initialize Rails. However, my personal
          # preference is to not change anything in the app (in this case,
          # environment.rb) to support Spin.
          def self.run(command = :preload, configuration = Configuration.new)
            yield configuration if block_given?
            initializer = new configuration
            initializer.send(command)
            initializer
          end

          # Runs the preload phase of the Rails initialization process.
          def preload
            Rails.configuration = configuration
            Rails2Preload.preload(self)
          end

          # Runs the postload phase of the Rails initialization process.
          def postload
            Rails2Preload.postload(self)
            Rails.initialized = true
          end
        end # Initializer
      end # Rails
    RUBY
  end

  # Returns a Pathname object. We'll use it to determine what the Rails root
  # is before the Rails module is available.
  def self.rails_root
    Bundler.root
  end

  def self.boot_rails
    require(rails_root + "config/boot")
  end

  def self.initialize_rails
    require(rails_root + "config/environment")
  end

  # Benchmarks a method sent to an object and prints the result.
  def self.benchmark(object, method, *args)
    print "[Rails2Preload] #{method}"
    seconds = Benchmark.realtime { object.send(method, *args) }
    puts "#{"%0.3f" % seconds}s".rjust(40 - method.length)
  end
end # Rails2Preload
