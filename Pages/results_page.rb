# path: pages/results_page.rb
require_relative 'base_page'
require_relative '../Locators/results_locators'

# ======================================
# ResultsPage
# Handles search results interactions and product collection.
# Optimized for fast execution — assumes stable and interactable UI.
# ======================================
class ResultsPage < BasePage
  include ResultsLocators

  # ===== Basic Actions =====
  def click_FILTER_BUTTON
    remember_last_action(__method__)
    click(FILTER_BUTTON)
  end

  def click_DELIVERY_FULL_if_present
    remember_last_action(__method__)
    driver.find_element(*normalize(DELIVERY_FULL)).click rescue nil
    true
  end

  def click_CONDITION_BUTTON
    remember_last_action(__method__)
    click(CONDITION_BUTTON)
  end

  def click_SORT_BY_BUTTON
    remember_last_action(__method__)
    click(SORT_BY_BUTTON)
  end

  def click_VIEW_RESULTS_BUTTON
    remember_last_action(__method__)
    click(VIEW_RESULTS_BUTTON)
  end

  # ===== Scroll Helpers =====
  def scroll_until_OPTION_NEW(max_swipes: 16)
    remember_last_action(__method__)
    found = scroll_until(OPTION_NEW, max_swipes: max_swipes, column_index: 1)
    raise Selenium::WebDriver::Error::NoSuchElementError, 'OPTION_NEW not visible after scrolling' unless found
    true
  end

  def scroll_until_SORT_BY_BUTTON(max_swipes: 16)
    remember_last_action(__method__)
    found = scroll_until(SORT_BY_BUTTON, max_swipes: max_swipes)
    raise Selenium::WebDriver::Error::NoSuchElementError, 'SORT_BY_BUTTON not visible after scrolling' unless found
    true
  end

  def scroll_until_SORT_BY_PRICE_DESC_BTN(max_swipes: 16)
    remember_last_action(__method__)
    found = scroll_until(SORT_BY_PRICE_DESC_BTN, max_swipes: max_swipes, column_index: 1)
    raise Selenium::WebDriver::Error::NoSuchElementError, 'SORT_BY_PRICE_DESC_BTN not visible after scrolling' unless found
    true
  end

  # ===== Problematic Buttons (simplified for Fast Mode) =====
  def click_OPTION_NEW
    remember_last_action(__method__)
    click(OPTION_NEW)
  end

  def click_SORT_BY_PRICE_DESC_BTN
    remember_last_action(__method__)
    begin
      scroll_until_SORT_BY_PRICE_DESC_BTN
    rescue StandardError
      # ignore if already visible
    end
    click(SORT_BY_PRICE_DESC_BTN)
  end

  # ===== Product Collection =====
  def collect_products_and_prices(max: 5, term: nil)
    remember_last_action(__method__)
    prev_wait = (driver.manage.timeouts.implicit_wait rescue nil)
    driver.manage.timeouts.implicit_wait = 0.8 rescue nil

    results = {}
    products, prices = [], []

    extractor = lambda do |card|
      texts = card.find_elements(xpath: './/android.widget.TextView')
      price_el = texts.find { |el| el.text =~ /\$/ }
      return nil unless price_el

      price_y = center_y(price_el)

      candidates = texts.select do |el|
        txt = el.text.strip
        next false if txt.empty?
        next false if txt =~ /\$/ || txt.length < 10
        next false if txt =~ /(envío|gratis|opción|compra|vendidos|meses|intereses|full|mejor precio|tienda|oficial)/i
        next false unless txt =~ /[A-Za-z]/
        next false unless txt =~ /[0-9]|playstation|ps5|sony|consola/i
        center_y(el) < price_y
      end

      name_el = candidates.min_by { |el| (price_y - center_y(el)).abs }
      return nil unless name_el

      name  = name_el.text.strip
      price = price_el.text.strip
      return nil if name.empty? || price.empty?

      price = price.gsub(/\[space\]|\[decimals\]/, '').gsub(/\s+/, ' ').strip
      key = "#{name}|#{price}"
      return nil if results.key?(key)

      results[key] = true
      [name, price, key]
    rescue => e
      warn "[WARN] Extractor error: #{e.message}"
      nil
    end

    more_products, more_prices = first_n_by_scroll(
      card_xpath: '//android.view.View[@resource-id="polycard_component"]',
      extractor: extractor,
      max: max,
      max_scrolls: 12
    )

    products.concat(more_products).uniq!
    prices.concat(more_prices).uniq!

    products = products.first(max)
    prices   = prices.first(max)

    puts "\nProducts: #{products.size}"
    products.each_with_index do |p, i|
      price = prices[i] || "N/A"
      puts "#{i + 1}. #{p}"
      puts "   Price: #{price}\n\n"
    end
    puts

    { products: products, prices: prices }
  ensure
    driver.manage.timeouts.implicit_wait = prev_wait rescue nil
  end

  def get_products_and_prices(max: 5, term: nil)
    collect_products_and_prices(max: max, term: term)
  end
end
