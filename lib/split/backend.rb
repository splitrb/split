require 'split/backends/redis'
module Split
  class Backend
    include Split::Backends::Redis
  end
end