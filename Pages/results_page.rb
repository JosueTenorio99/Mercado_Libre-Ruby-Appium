# path: pages/results_page.rb
require_relative 'base_page'
require_relative '../Locators/results_locators'

class ResultsPage < BasePage
  include ResultsLocators

  def click_FILTER_BUTTON(timeout: 5)
    remember_last_action(__method__)
    click(FILTER_BUTTON, timeout: timeout)
    true
  end

  def click_DELIVERY_FULL_if_present(timeout: 3)
    remember_last_action(__method__)
    el = try_find(DELIVERY_FULL, timeout: timeout)
    el&.click
    true
  end

  def click_CONDITION_BUTTON(timeout: 5)
    remember_last_action(__method__)
    click(CONDITION_BUTTON, timeout: timeout)
    true
  end

  def click_OPTION_NEW(timeout: 5)
    remember_last_action(__method__)
    click(OPTION_NEW, timeout: timeout)
    true
  end

  def scroll_until_SORT_BY_BUTTON(max_swipes: 16)
    remember_last_action(__method__)
    found = scroll_until(SORT_BY_BUTTON, max_swipes: max_swipes)
    raise Selenium::WebDriver::Error::NoSuchElementError, 'SORT_BY_BUTTON not visible after scrolling' unless found
    true
  end

  def click_SORT_BY_BUTTON(timeout: 5)
    remember_last_action(__method__)
    click(SORT_BY_BUTTON, timeout: timeout)
    true
  end

  def click_SORT_BY_PRICE_DESC_BTN(timeout: 5)
    remember_last_action(__method__)
    click(SORT_BY_PRICE_DESC_BTN, timeout: timeout)
    true
  end

  def click_VIEW_RESULTS_BUTTON(timeout: 5)
    remember_last_action(__method__)
    click(VIEW_RESULTS_BUTTON, timeout: timeout)
    true
  end

  # Robust results reader with deduplication
  def collect_products_and_prices(max: 5, term: nil)
    remember_last_action(__method__)
    prev_wait = (driver.manage.timeouts.implicit_wait rescue nil)
    driver.manage.timeouts.implicit_wait = 0.8 rescue nil

    extractor = lambda do |card|
      # Prefer an explicit "now price"; fallback to any price candidate
      price_el = begin
                   p = card.find_elements(xpath: PRICE_NOW_XPATH).first
                   p ||= card.find_elements(xpath: PRICE_ANY_XPATH).last
                   p
                 rescue StandardError
                   nil
                 end
      return nil if price_el.nil?

      # Title by id or heuristic (must be visually above the price)
      name_el = begin
                  by_id = card.find_elements(xpath: TITLE_ID_IN_CARD_XPATH)
                  if by_id.any?
                    by_id.first
                  else
                    candidates = card.find_elements(xpath: TITLE_ANY_IN_CARD_XP)
                    candidates = candidates.select { |e| looks_like_title?(e.text) }
                    candidates = candidates.select { |e| center_y(e) < center_y(price_el) }
                    largest_by_bounds(candidates)
                  end
                rescue StandardError
                  nil
                end
      return nil unless name_el

      name = name_el.text
      return nil unless includes_ci?(name, term)

      price = price_el.attribute('content-desc') rescue nil
      return nil if price.nil? || price.strip.empty?

      [name, price]
    end

    productos, precios = first_n_by_scroll(
      card_xpath:  POLYCARD_XPATH,
      extractor:   extractor,
      max:         max,
      max_scrolls: 12
    )

    puts "Products: #{productos.size}"
    productos.each_with_index do |p, i|
      puts "  #{i + 1}. #{p}"
      puts "     $ #{precios[i]}"
    end

    { productos: productos, precios: precios }
  ensure
    driver.manage.timeouts.implicit_wait = prev_wait rescue nil
  end

  # Convenience alias in Spanish kept for compatibility
  def obtener_productos_y_precios(max: 5, term: nil)
    collect_products_and_prices(max: max, term: term)
  end
end
