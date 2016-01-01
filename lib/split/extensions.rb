# frozen_string_literal: true
%w[array string].each do |f|
  require "split/extensions/#{f}"
end
