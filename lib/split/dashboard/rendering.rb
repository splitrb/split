# frozen_string_literal: true

require 'split/dashboard/helpers'
require 'split/dashboard/pagination_helpers'

module Split
  class Dashboard
    module Rendering
      VIEWS_PATH = File.join(
        File.dirname(File.expand_path(__FILE__)),
        'views'
      )

      def render_erb(view)
        [200, {}, [erb(view)]]
      end

      def erb(view, opts = {})
        render_layout do
          partial(view, opts)
        end
      end

      def partial(view, opts = {})
        filename = view.to_s + '.erb'
        file_path = File.join(VIEWS_PATH, filename)
        raw = File.read(file_path)
        b = binding
        (opts[:locals] || {}).each do |k, v|
          b.local_variable_set(k, v)
        end
        ERB.new(raw).result(b)
      end

      def render_layout(&block)
        partial(:layout, &block)
      end

      def redirect(url)
        response.redirect(url)
        response.finish
      end

      include Split::DashboardHelpers
      include Split::DashboardPaginationHelpers
    end
  end
end
