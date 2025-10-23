# path: pages/results_page.rb
require_relative 'base_page'
require_relative '../Locators/results_locators'

class ResultsPage < BasePage
  include ResultsLocators

  # ===== Acciones básicas =====
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

  def click_SORT_BY_BUTTON(timeout: 5)
    remember_last_action(__method__)
    click(SORT_BY_BUTTON, timeout: timeout)
    true
  end

  def click_VIEW_RESULTS_BUTTON(timeout: 5)
    remember_last_action(__method__)
    click(VIEW_RESULTS_BUTTON, timeout: timeout)
    true
  end

  # ===== Scroll helpers =====
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

  # ===== Botones problemáticos (ahora delegan al helper genérico) =====
  def click_OPTION_NEW(*args, timeout: 5, **kwargs)
    timeout = args.first if args.first.is_a?(Numeric)
    timeout = kwargs[:timeout] if kwargs.key?(:timeout)
    remember_last_action(__method__)

    success_probe = -> do
      el = try_find(OPTION_NEW, timeout: 0.6) { |e| (e.displayed? rescue true) }
      el && (el.attribute('checked') rescue 'false') == 'true'
    end

    click(OPTION_NEW, timeout: timeout, smart: true, success: success_probe)
  end


  def click_SORT_BY_PRICE_DESC_BTN(*args, timeout: 5, **kwargs)
    timeout = args.first if args.first.is_a?(Numeric)
    timeout = kwargs[:timeout] if kwargs.key?(:timeout)
    remember_last_action(__method__)

    # por si acaso, asegúrate de tenerlo a la vista siempre
    begin
      scroll_until_SORT_BY_PRICE_DESC_BTN
    rescue StandardError
    end

    success_probe = -> do
      el = try_find(SORT_BY_PRICE_DESC_BTN, timeout: 0.6) { |e| (e.displayed? rescue true) }
      el && (el.attribute('checked') rescue 'false') == 'true'
    end

    click(SORT_BY_PRICE_DESC_BTN, timeout: timeout, smart: true, success: success_probe)
  end


  # ===== Recolección de productos (igual que antes) =====
  def collect_products_and_prices(max: 5, term: nil)
    remember_last_action(__method__)
    prev_wait = (driver.manage.timeouts.implicit_wait rescue nil)
    driver.manage.timeouts.implicit_wait = 0.8 rescue nil

    results = {}
    products, prices = [], []

    extractor = lambda do |card|
      begin
        texts = card.find_elements(xpath: './/android.widget.TextView')
        price_el = texts.find { |el| el.text =~ /\$/ }
        return nil if price_el.nil?

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

        name_el = candidates.sort_by { |el| (price_y - center_y(el)).abs }.first
        return nil if name_el.nil?

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
