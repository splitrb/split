class CookiesMock

  def initialize
    @cookies = {}
  end

  def []=(key, value)
    @cookies[key] = value[:value]
  end

  def [](key)
    @cookies[key]
  end

  def delete(key)
    @cookies.delete(key)
  end

end