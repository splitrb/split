# frozen_string_literal: true
class Redis
  alias_method :exists?, :exists unless Redis.method_defined? :exists?
end
