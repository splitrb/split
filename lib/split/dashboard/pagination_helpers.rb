# frozen_string_literal: true

require 'split/dashboard/paginator'

module Split
  module DashboardPaginationHelpers
    def pagination_per
      default_per_page = Split.configuration.dashboard_pagination_default_per_page
      @pagination_per ||= (params['per'] || default_per_page).to_i
    end

    def page_number
      @page_number ||= (params['page'] || 1).to_i
    end

    def paginated(collection)
      Split::DashboardPaginator.new(collection, page_number, pagination_per).paginate
    end

    def pagination(collection)
      html = []
      html << first_page_tag if show_first_page_tag?
      html << ellipsis_tag if show_first_ellipsis_tag?
      html << prev_page_tag if show_prev_page_tag?
      html << current_page_tag
      html << next_page_tag if show_next_page_tag?(collection)
      html << ellipsis_tag if show_last_ellipsis_tag?(collection)
      html << last_page_tag(collection) if show_last_page_tag?(collection)
      html.join
    end

    private

    def show_first_page_tag?
      page_number > 2
    end

    def first_page_tag
      %Q(<a href="#{url.chop}?page=1&per=#{pagination_per}">1</a>)
    end

    def show_first_ellipsis_tag?
      page_number >= 4
    end

    def ellipsis_tag
      '<span>...</span>'
    end

    def show_prev_page_tag?
      page_number > 1
    end

    def prev_page_tag
      %Q(<a href="#{url.chop}?page=#{page_number - 1}&per=#{pagination_per}">#{page_number - 1}</a>)
    end

    def current_page_tag
      "<span><b>#{page_number}</b></span>"
    end

    def show_next_page_tag?(collection)
      (page_number * pagination_per) < collection.count
    end

    def next_page_tag
      %Q(<a href="#{url.chop}?page=#{page_number + 1}&per=#{pagination_per}">#{page_number + 1}</a>)
    end

    def show_last_ellipsis_tag?(collection)
      (total_pages(collection) - page_number) >= 3
    end

    def total_pages(collection)
      collection.count / pagination_per + ((collection.count % pagination_per).zero? ? 0 : 1)
    end

    def show_last_page_tag?(collection)
      page_number < (total_pages(collection) - 1)
    end

    def last_page_tag(collection)
      total = total_pages(collection)
      %Q(<a href="#{url.chop}?page=#{total}&per=#{pagination_per}">#{total}</a>)
    end
  end
end
