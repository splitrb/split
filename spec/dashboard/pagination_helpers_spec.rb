require 'spec_helper'
require 'split/dashboard/pagination_helpers'

describe Split::DashboardPaginationHelpers do
  include Split::DashboardPaginationHelpers

  let(:url) { '/split/' }

  describe '#pagination_per' do
    context 'when params empty' do
      let(:params) { { } }

      it 'returns the default (10)' do
        default_per_page = Split.configuration.dashboard_pagination_default_per_page
        expect(pagination_per).to eql default_per_page
        expect(pagination_per).to eql 10
      end
    end

    context 'when params[:per] is 5' do
      let(:params) { { 'per' => '5' } }

      it 'returns 5' do
        expect(pagination_per).to eql 5
      end
    end
  end

  describe '#page_number' do
    context 'when params empty' do
      let(:params) { { } }

      it 'returns 1' do
        expect(page_number).to eql 1
      end
    end

    context 'when params[:page] is "2"' do
      let(:params) { { 'page' => '2' } }

      it 'returns 2' do
        expect(page_number).to eql 2
      end
    end
  end

  describe '#paginated' do
    let(:collection) { (1..20).to_a }
    let(:params) { { 'per' => '5', 'page' => '3' } }

    it { expect(paginated(collection)).to eql [11, 12, 13, 14, 15] }
  end

  describe '#show_first_page_tag?' do
    context 'when page is 1' do
      it { expect(show_first_page_tag?).to be false }
    end

    context 'when page is 3' do
      let(:params) { { 'page' => '3' } }
      it { expect(show_first_page_tag?).to be true }
    end
  end

  describe '#first_page_tag' do
    it { expect(first_page_tag).to eql '<a href="/split?page=1&per=10">1</a>' }
  end

  describe '#show_first_ellipsis_tag?' do
    context 'when page is 1' do
      it { expect(show_first_ellipsis_tag?).to be false }
    end

    context 'when page is 4' do
      let(:params) { { 'page' => '4' } }
      it { expect(show_first_ellipsis_tag?).to be true }
    end
  end

  describe '#ellipsis_tag' do
    it { expect(ellipsis_tag).to eql '<span>...</span>' }
  end

  describe '#show_prev_page_tag?' do
    context 'when page is 1' do
      it { expect(show_prev_page_tag?).to be false }
    end

    context 'when page is 2' do
      let(:params) { { 'page' => '2' } }
      it { expect(show_prev_page_tag?).to be true }
    end
  end

  describe '#prev_page_tag' do
    context 'when page is 2' do
      let(:params) { { 'page' => '2' } }

      it do
        expect(prev_page_tag).to eql '<a href="/split?page=1&per=10">1</a>'
      end
    end

    context 'when page is 3' do
      let(:params) { { 'page' => '3' } }

      it do
        expect(prev_page_tag).to eql '<a href="/split?page=2&per=10">2</a>'
      end
    end
  end

  describe '#show_prev_page_tag?' do
    context 'when page is 1' do
      it { expect(show_prev_page_tag?).to be false }
    end

    context 'when page is 2' do
      let(:params) { { 'page' => '2' } }
      it { expect(show_prev_page_tag?).to be true }
    end
  end

  describe '#current_page_tag' do
    context 'when page is 1' do
      let(:params) { { 'page' => '1' } }
      it { expect(current_page_tag).to eql '<span><b>1</b></span>' }
    end

    context 'when page is 2' do
      let(:params) { { 'page' => '2' } }
      it { expect(current_page_tag).to eql '<span><b>2</b></span>' }
    end
  end

  describe '#show_next_page_tag?' do
    context 'when page is 2' do
      let(:params) { { 'page' => '2' } }

      context 'when collection length is 20' do
        let(:collection) { (1..20).to_a }
        it { expect(show_next_page_tag?(collection)).to be false }
      end

      context 'when collection length is 25' do
        let(:collection) { (1..25).to_a }
        it { expect(show_next_page_tag?(collection)).to be true }
      end
    end
  end

  describe '#next_page_tag' do
    context 'when page is 1' do
      let(:params) { { 'page' => '1' } }
      it { expect(next_page_tag).to eql '<a href="/split?page=2&per=10">2</a>' }
    end

    context 'when page is 2' do
      let(:params) { { 'page' => '2' } }
      it { expect(next_page_tag).to eql '<a href="/split?page=3&per=10">3</a>' }
    end
  end

  describe '#total_pages' do
    context 'when collection length is 30' do
      let(:collection) { (1..30).to_a }
      it { expect(total_pages(collection)).to eql 3 }
    end

    context 'when collection length is 35' do
      let(:collection) { (1..35).to_a }
      it { expect(total_pages(collection)).to eql 4 }
    end
  end

  describe '#show_last_ellipsis_tag?' do
    let(:collection) { (1..30).to_a }
    let(:params) { { 'per' => '5', 'page' => '2' } }
    it { expect(show_last_ellipsis_tag?(collection)).to be true }
  end

  describe '#show_last_page_tag?' do
    let(:collection) { (1..30).to_a }

    context 'when page is 5/6' do
      let(:params) { { 'per' => '5', 'page' => '5' } }
      it { expect(show_last_page_tag?(collection)).to be false }
    end

    context 'when page is 4/6' do
      let(:params) { { 'per' => '5', 'page' => '4' } }
      it { expect(show_last_page_tag?(collection)).to be true }
    end
  end

  describe '#last_page_tag' do
    let(:collection) { (1..30).to_a }
    it { expect(last_page_tag(collection)).to eql '<a href="/split?page=3&per=10">3</a>' }
  end
end
