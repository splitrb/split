class Array
  # maintain backwards compatibility with 1.8.7
  alias_method :sample, :choice unless method_defined?(:sample)
end