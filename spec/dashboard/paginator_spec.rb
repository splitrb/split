# frozen_string_literal: true
require 'spec_helper'
require 'split/dashboard/paginator'

describe Split::DashboardPaginator do
  context 'when collection is 1..20' do
    let(:collection) { (1..20).to_a }

    context 'when per 5 for page' do
      let(:per) { 5 }

      it 'when page number is 1 result is [1, 2, 3, 4, 5]' do
        result = Split::DashboardPaginator.new(collection, 1, per).paginate
        expect(result).to eql [1, 2, 3, 4, 5]
      end

      it 'when page number is 2 result is [6, 7, 8, 9, 10]' do
        result = Split::DashboardPaginator.new(collection, 2, per).paginate
        expect(result).to eql [6, 7, 8, 9, 10]
      end
    end

    context 'when per 10 for page' do
      let(:per) { 10 }

      it 'when page number is 1 result is [1..10]' do
        result = Split::DashboardPaginator.new(collection, 1, per).paginate
        expect(result).to eql [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      end

      it 'when page number is 2 result is [10..20]' do
        result = Split::DashboardPaginator.new(collection, 2, per).paginate
        expect(result).to eql [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
      end
    end
  end
end
