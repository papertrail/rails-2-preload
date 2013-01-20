require "test/unit"

class Rails2PreloadTest < Test::Unit::TestCase
  def setup
    # Use Kernel.load instead of Kernel.require so the objects can be reloaded
    # after being removed in the teardown step.
    load "rails_2_preload.rb"
    load "mocks/spin.rb"
    load "mocks/active_record.rb"
    load "mocks/rails.rb"

    # Patch a couple Rails2Preload methods that use Kernel.require.
    def Rails2Preload.boot_rails
      Rails.boot!
    end

    def Rails2Preload.initialize_rails
      Rails::Initializer.run
    end

    # Add the Spin hooks.
    Rails2Preload.add_spin_hooks
  end

  def teardown
    # Remove all the loaded objects so the next test beings with a completely
    # "clean" environment.
    Object.send(:remove_const, :Rails2Preload) if defined?(Rails2Preload)
    Object.send(:remove_const, :Spin)          if defined?(Spin)
    Object.send(:remove_const, :ActiveRecord)  if defined?(ActiveRecord)
    Object.send(:remove_const, :Rails)         if defined?(Rails)
  end

  # Test that the Spin hooks have been added.
  def test_add_spin_hooks
    [:before_preload, :after_preload, :after_fork].each do |name|
      hooks = Spin._hooks(name)

      refute       hooks.empty?
      assert_equal 1, hooks.count
      assert       hooks.first.is_a?(Proc)
    end

    assert Spin._hooks(:before_fork).empty?
  end

  # Test that the Rails 2 initializer is patched when the before_preload hook
  # in executed.
  def test_before_preload
    Spin.execute_hook(:before_preload)

    assert Rails::Initializer.respond_to?(:run)
    assert Rails::Initializer.new(Rails::Configuration.new).respond_to?(:preload)
    assert Rails::Initializer.new(Rails::Configuration.new).respond_to?(:postload)
  end

  # Test that Rails is preloaded when initialized.
  def test_initialize_rails
    Spin.execute_hook(:before_preload)
    Rails2Preload.initialize_rails

    assert_equal Rails2Preload.preload_methods, Rails.methods_called
  end

  # Test that the ActiveRecord connection pool is *not* disconnected if the
  # classes are *not* preloaded when the after_preload hook is executed.
  def test_after_preload_classes_not_preloaded
    refute Rails2Preload.preload_methods.include?(:load_application_classes)

    Spin.execute_hook(:before_preload)
    Rails2Preload.initialize_rails
    Spin.execute_hook(:after_preload)

    refute ActiveRecord::Base.connection_pool.disconnected?
  end

  # Test that the ActiveRecord connection pool *is* disconnected if the
  # classes *are* preloaded when the after_preload hook is executed.
  def test_after_preload_classes_are_preloaded
    Rails2Preload.preload_until(:disable_dependency_loading)
    assert Rails2Preload.preload_methods.include?(:load_application_classes)

    Spin.execute_hook(:before_preload)
    Rails2Preload.initialize_rails
    Spin.execute_hook(:after_preload)

    assert ActiveRecord::Base.connection_pool.disconnected?
  end

  # Test that Rails is fully loaded by the time the after_fork hook is
  # executed.
  def test_after_fork
    Spin.execute_hook(:before_preload)
    Rails2Preload.initialize_rails
    Spin.execute_hook(:after_preload)
    Spin.execute_hook(:before_fork)
    Spin.execute_hook(:after_fork)

    assert_equal (Rails2Preload.preload_methods + Rails2Preload.postload_methods), Rails.methods_called
  end
end
