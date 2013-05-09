module Rails2Preload
  module Spin

    # By default, we'll preload until the application classes (i.e. models) are
    # loaded. This is optimal for unit testing.
    Rails2Preload.preload_until(:load_application_classes)

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

  end
end
