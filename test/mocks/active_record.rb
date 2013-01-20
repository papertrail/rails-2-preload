module ActiveRecord
  class ConnectionPool
    def disconnect!
      @disconnected = true
    end

    # Returns +true+ if the #disconnect! method has been called.
    def disconnected?
      @disconnected
    end
  end # ConnectionPool

  class Base
    def self.connection_pool
      @connection_pool ||= ConnectionPool.new
    end
  end # Base
end # ActiveRecord
