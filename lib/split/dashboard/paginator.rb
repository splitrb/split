# frozen_string_literal: true
module Split
  class DashboardPaginator
    def initialize(collection, page_number, per)
      @collection = collection
      @page_number = page_number
      @per = per
    end

    def paginate
      to = @page_number * @per
      from = to - @per
      @collection[from...to]
    end
  end
end
