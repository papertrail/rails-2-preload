module Rails
  class << self
    attr_accessor :configuration,
                  :initialized,
                  :methods_called
  end

  def self.boot!; end

  # Initialize an array that will store the initializer methods called. Used
  # in the tests to determine how far along the initialization process is.
  self.methods_called = Array.new

  class Initializer
    attr_reader :configuration

    def initialize(configuration)
      raise ArgumentError unless configuration.is_a?(Configuration)

      @configuration = configuration
    end

    # Define the Rails initialization methods based upon the list known to
    # Rails2Preload.
    Rails2Preload::METHODS.each do |method|
      define_method(method) do
        Rails.methods_called << method
      end
    end
  end

  class Configuration; end
end
