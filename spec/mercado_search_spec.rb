# path: spec/mercado_search_spec.rb
require_relative 'spec_helper'
require_relative '../pages/start_page'
require_relative '../pages/home_page'
require_relative '../pages/results_page'

RSpec.describe 'Mercado Libre Search Flow' do
  before(:all) do
    @driver  = $driver
    @start   = StartPage.new(@driver)
    @home    = HomePage.new(@driver)
    @results = ResultsPage.new(@driver)
  end

  it 'search products and applies filters with screenshots' do
    @start.click_CONTINUE_AS_GUEST_BUTTON
    @start.save_SCREENSHOT

    @home.click_SEARCH_BAR
    @home.save_SCREENSHOT

    @home.send_keys_SEARCH_INPUT_and_submit('PlayStation 5')
    @home.save_SCREENSHOT

    @results.click_FILTER_BUTTON
    @results.save_SCREENSHOT

    @results.click_DELIVERY_FULL_if_present
    @results.save_SCREENSHOT

    @results.scroll_until_OPTION_NEW
    @results.save_SCREENSHOT

    @results.click_OPTION_NEW
    @results.save_SCREENSHOT

    @results.scroll_until_SORT_BY_PRICE_DESC_BTN
    @results.save_SCREENSHOT

    @results.click_SORT_BY_PRICE_DESC_BTN
    @results.save_SCREENSHOT

    @results.click_VIEW_RESULTS_BUTTON
    @results.save_SCREENSHOT

    @results.collect_products_and_prices(max: 5)
    @results.save_SCREENSHOT
  end
end
