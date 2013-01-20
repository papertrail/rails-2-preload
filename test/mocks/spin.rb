module Spin
  HOOKS = [:before_fork, :after_fork, :before_preload, :after_preload]

  def self.hook(name, &block)
    raise unless HOOKS.include?(name)
    _hooks(name) << block
  end

  def self.execute_hook(name)
    raise unless HOOKS.include?(name)
    _hooks(name).each(&:call)
  end

  def self._hooks(name)
    @hooks ||= {}
    @hooks[name] ||= []
    @hooks[name]
  end
end
