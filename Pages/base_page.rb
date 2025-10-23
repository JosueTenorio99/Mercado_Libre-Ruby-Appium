# path: pages/base_page.rb
require 'fileutils'
require 'base64'
require 'set'
require 'tempfile'

class BasePage
  attr_reader :driver

  def initialize(driver = $driver)
    @driver = driver
  end

  def remember_last_action(sym)
    @__last_action = sym.to_s
  end

  def last_action_name
    @__last_action || 'unknown_action'
  end

  def next_screenshot_index
    Thread.current[:screenshot_index] = (Thread.current[:screenshot_index] || 0) + 1
  end

  def wait_until(timeout: 3.0, interval: 0.10)
    deadline = monotonic_now + timeout.to_f
    loop do
      return true if yield
      break if monotonic_now >= deadline
      sleep interval
    end
    false
  end

  def elements(locator)
    driver.find_elements(*normalize(locator))
  rescue StandardError
    []
  end

  def present?(locator)
    !elements(locator).empty?
  end

  def find!(locator)
    driver.find_element(*normalize(locator))
  end

  def try_find(locator, timeout: 3.0, interval: 0.10)
    el = nil
    ok = wait_until(timeout: timeout, interval: interval) do
      el = find!(locator) rescue nil
      el && (!block_given? || yield(el))
    end
    ok ? el : nil
  end

  def click(locator, timeout: 6.0, settle: 0.35, retries: 1, smart: false, success: nil)
    el = try_find(locator, timeout: timeout) { |e| interactable?(e) }
    raise "Not clickable: #{locator.inspect}" unless el

    # Minimiza interferencias comunes
    (driver.hide_keyboard rescue nil)

    # Centra si está muy abajo (mejor hitbox)
    begin
      if smart
        h  = driver.manage.window.size.height
        cy = center_y(el)
        if cy > (h * 0.87)
          scroll_down(percent: 0.5)
          sleep 0.12
          el = try_find(locator, timeout: 1.0) { |e| interactable?(e) } || el
        end
      end
    rescue StandardError
    end

    sleep settle
    old_sig = page_signature
    succeeded = false

    toggle_like = lambda do |e|
      (e.attribute('checked')  rescue 'false') == 'true' ||
        (e.attribute('selected') rescue 'false') == 'true' ||
        !(e.find_elements(xpath: ".//*[@checked='true' or @selected='true']") rescue []).empty?
    end

    (retries + 1).times do
      begin
        el.click
      rescue Selenium::WebDriver::Error::ElementClickInterceptedError,
        Selenium::WebDriver::Error::StaleElementReferenceError
        el = try_find(locator, timeout: 1.2) { |e| interactable?(e) }
        el&.click
      end
      sleep 0.15 if smart

      if smart
        verify = lambda do
          ok_block = success && begin; success.call; rescue; false; end
          ok_toggle = begin
                        e2 = try_find(locator, timeout: 0.8) { |e| interactable?(e) }
                        e2 && toggle_like.call(e2)
                      rescue
                        false
                      end
          ok_dom = page_signature != old_sig
          ok_block || ok_toggle || ok_dom
        end

        succeeded = wait_until(timeout: 2.5, interval: 0.10) { verify.call }
        break if succeeded
      else
        return true
      end
    end

    # Fallback: click por coordenadas (clickGesture)
    if smart && !succeeded
      begin
        ctx = driver.respond_to?(:current_context) ? driver.current_context.to_s : 'NATIVE_APP'
        if !ctx.include?('WEBVIEW')
          l, t, r, b = bounds_rect(el)
          x = (l + r) / 2
          y = (t + b) / 2
          driver.execute_script('mobile: clickGesture', { 'x' => x, 'y' => y })
          sleep 0.12
          verify = lambda do
            ok_block = success && begin; success.call; rescue; false; end
            ok_toggle = begin
                          e3 = try_find(locator, timeout: 0.8) { |e| interactable?(e) }
                          e3 && toggle_like.call(e3)
                        rescue
                          false
                        end
            ok_dom = page_signature != old_sig
            ok_block || ok_toggle || ok_dom
          end
          succeeded = wait_until(timeout: 2.5, interval: 0.10) { verify.call }
        end
      rescue StandardError
      end
    end

    return true if smart ? succeeded : true
    raise "Failed to click #{locator.inspect} (smart mode: no success detected)"
  end

  # =====================================================
  # Fin del método click inteligente
  # =====================================================

  def save_SCREENSHOT(name: nil, folder: nil, wait_for_idle: true, settle_ms: 180)
    settle_for_screenshot(settle_ms: settle_ms) if wait_for_idle
    test_class  = current_test_class_name
    base_folder = folder || File.join("screenshots", test_class)
    FileUtils.mkdir_p(base_folder) rescue nil

    idx       = next_screenshot_index
    prefix    = format("%02d", idx)
    timestamp = Time.now.strftime("%Y%m%d-%H%M%S-%L")
    base      = (name && !name.to_s.empty?) ? name.to_s : last_action_name
    filename  = "#{prefix}_#{base}_#{timestamp}.png"
    path      = File.join(base_folder, filename)

    write_screenshot!(path)

    if defined?(Allure)
      begin
        png_data = File.binread(path)
        Tempfile.create(["allure_attachment_", ".png"]) do |tmp|
          tmp.binmode
          tmp.write(png_data)
          tmp.flush
          Allure.add_attachment(
            name: base,
            source: File.open(tmp.path, 'rb'),
            type: Allure::ContentType::PNG,
            test_case: true
          )
        end
      rescue => e
        warn "[Allure] Failed to attach screenshot #{path}: #{e.class}: #{e.message}"
      end
    end
    path
  end

  def attach_text_to_allure(name, text)
    Allure.add_attachment(
      name: name.to_s,
      source: text.to_s,
      type: Allure::ContentType::TXT,
      test_case: true
    )
  rescue StandardError
  end

  def ui_loading_present?
    xpaths = [
      '//android.widget.ProgressBar',
      '//*[@resource-id="android:id/progress"]',
      '//*[contains(@text,"Loading")]',
      '//*[contains(@content-desc,"Loading")]'
    ]
    xpaths.any? { |xp| driver.find_elements(xpath: xp)&.any? }
  rescue StandardError
    false
  end

  def wait_for_ui_idle(timeout: 5.0, stable_duration: 0.4, poll: 0.08)
    deadline = monotonic_now + timeout
    prev_sig = nil
    stable_since = nil

    while monotonic_now < deadline
      sig = page_signature
      if !ui_loading_present? && prev_sig == sig
        stable_since ||= monotonic_now
        return true if (monotonic_now - stable_since) >= stable_duration
      else
        stable_since = nil
      end
      prev_sig = sig
      sleep poll
    end
    false
  end

  def page_signature
    driver.page_source.hash
  rescue StandardError
    monotonic_now.to_i
  end

  def scroll_down(percent: 0.95, column_index: 0)
    size = driver.manage.window.size
    top  = (size.height * 0.20).to_i
    h    = (size.height * 0.60).to_i

    begin
      driver.execute_script(
        'mobile: scrollGesture',
        { 'left' => 0, 'top' => top, 'width' => size.width, 'height' => h,
          'direction' => 'down', 'percent' => percent }
      )
      true
    rescue StandardError
      # fallback to UiScrollable — use custom column index (0 = full list, 1 = right column)
      begin
        script = "new UiScrollable(new UiSelector().scrollable(true).instance(#{column_index})).scrollForward()"
        driver.find_element(:uiautomator, script)
        true
      rescue StandardError
        false
      end
    end
  end

  def wait_dom_change_or_new(card_xpath:, old_sig:, old_count:, timeout: 1.4, poll: 0.05)
    deadline = monotonic_now + timeout
    while monotonic_now < deadline
      sig = page_signature
      count = driver.find_elements(xpath: card_xpath).size
      return :new_items if count > old_count
      return :changed if sig != old_sig
      sleep poll
    end
    :no_change
  end

  def first_n_by_scroll(card_xpath:, extractor:, max:, max_scrolls: 8)
    products = []
    prices = []
    seen_keys = Set.new
    consecutive_nochange = 0

    max_scrolls.times do
      cards = driver.find_elements(xpath: card_xpath)
      cards.each do |card|
        data = safe_call { extractor.call(card) }
        next unless data

        name, price, key = data
        key ||= "#{name}|#{price}"

        # Skip duplicates already seen
        next if seen_keys.include?(key)

        products << name
        prices  << price
        seen_keys << key

        # Stop early if max reached
        return [products.first(max), prices.first(max)] if products.size >= max
      end

      # Scroll and wait for DOM change
      old_sig   = page_signature
      old_count = driver.find_elements(xpath: card_xpath).size
      break unless scroll_down(percent: 0.94)

      change = wait_dom_change_or_new(
        card_xpath: card_xpath,
        old_sig: old_sig,
        old_count: old_count,
        timeout: 2.0
      )

      sleep 0.15 if change != :no_change

      consecutive_nochange = (change == :no_change) ? consecutive_nochange + 1 : 0
      break if consecutive_nochange >= 2
    end

    [products.first(max), prices.first(max)]
  end


  def scroll_to_text(text, max_swipes: 16, column_index: 0)
    uis = []
    0.upto(3) do |i|
      uis << "new UiScrollable(new UiSelector().scrollable(true).instance(#{column_index})).scrollTextIntoView(\"#{text}\")"
      uis << "new UiScrollable(new UiSelector().scrollable(true).instance(#{column_index})).scrollIntoView(new UiSelector().textContains(\"#{text}\"))"
    end

    uis.each { |script| return true if safe_call { driver.find_element(:uiautomator, script) } }

    xp = "//*[contains(@text, \"#{text}\")]"
    return true if driver.find_elements(xpath: xp).any?

    max_swipes.times do
      break unless scroll_down(percent: 0.96, column_index: column_index)
      sleep 0.08
      return true if driver.find_elements(xpath: xp).any?
    end
    false
  end

  def scroll_until(locator, max_swipes: 16, column_index: 0)
    return true if present?(locator)
    max_swipes.times do
      break unless scroll_down(percent: 1, column_index: column_index)
      sleep 0.15
      return true if present?(locator)
    end
    false
  end

  def largest_by_bounds(elements)
    elements.max_by do |el|
      b = safe_call { el.attribute('bounds') }
      next 0 unless b && b =~ /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/
      w = $3.to_i - $1.to_i
      h = $4.to_i - $2.to_i
      w * h
    end
  end

  def includes_ci?(text, needle)
    return true if needle.nil? || needle.to_s.strip.empty?
    (text || '').downcase.include?(needle.to_s.downcase)
  end

  def looks_like_title?(text)
    t = (text || '').strip
    return false if t.empty?

    td = t.downcase
    banned = %w[
    gratis envío envio llega mañana hoy cuotas meses oferta ofertas % off descuento descuentos prime full
    seller vendedor tienda tienda_oficial tienda-oficial tiendaoficial oficial store sponsored patrocinado anuncio anuncios ad ads
    visit visita marca brand garantía garantias vendidos vendido opiniones opinión reseñas reseña review reviews calificación
    rating puntos estrella estrellas official
  ]

    # New: take only first line (some titles include seller info below)
    first_line = td.split("\n").first.to_s.strip
    return false if banned.any? { |w| first_line.include?(w) }

    # Basic sanity checks
    return false if first_line =~ /\A[\s\-\+\|\.,\d]+\z/
    return false if first_line =~ /\b\d(?:\.\d)?\s*\|\s*\+\d/
    return false if first_line =~ /★|⭐|☆/

    has_letters = first_line.count('A-Za-zÁÉÍÓÚáéíóúÜüÑñ') >= 3
    return false unless has_letters
    return false if first_line.length < 8
    first_line.split.size >= 2
  end


  def bounds_rect(el)
    b = safe_call { el.attribute('bounds') }
    return [0, 0, 0, 0] unless b && b =~ /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/
    [$1.to_i, $2.to_i, $3.to_i, $4.to_i]
  end

  def center_y(el)
    r = bounds_rect(el)
    (r[1] + r[3]) / 2.0
  end

  private

  def interactable?(el)
    (el.displayed? rescue true) && (el.enabled? rescue true)
  end

  def snapshot_keys(card_xpath, extractor)
    driver.find_elements(xpath: card_xpath).map do |c|
      safe_call do
        t = extractor.call(c)
        t && (t[2] || "#{t[0]}|#{t[1]}")
      end
    end.compact
  end

  def settle_for_screenshot(settle_ms:)
    begin
      ctx = driver.respond_to?(:current_context) ? driver.current_context.to_s : ''
      if ctx.include?('WEBVIEW')
        state = driver.execute_script('return document.readyState') rescue 'complete'
        sleep 0.05 unless %w[interactive complete].include?(state.to_s)
        driver.execute_async_script(<<~JS) rescue nil
          var cb = arguments[arguments.length - 1];
          requestAnimationFrame(function(){ requestAnimationFrame(cb); });
        JS
      else
        sleep([settle_ms, 200].min / 1000.0)
      end
    rescue StandardError
    end
  end

  def write_screenshot!(path)
    drv = driver
    if drv.respond_to?(:save_screenshot)
      drv.save_screenshot(path)
      return
    end
    if drv.respond_to?(:screenshot_as)
      File.open(path, 'wb') { |f| f.write(Base64.decode64(drv.screenshot_as(:base64))) }
      return
    end
    if drv.respond_to?(:driver) && drv.driver.respond_to?(:save_screenshot)
      drv.driver.save_screenshot(path)
      return
    end
    raise NoMethodError, 'No public screenshot method available (save_screenshot / screenshot_as).'
  end

  def current_test_class_name
    return 'UnknownSpec' unless defined?(RSpec) && RSpec.respond_to?(:current_example) && RSpec.current_example
    group = RSpec.current_example.example_group rescue nil
    klass = group&.described_class
    return klass.name if klass && klass.respond_to?(:name) && klass.name
    file = RSpec.current_example.file_path rescue nil
    return 'UnknownSpec' unless file
    base = File.basename(file, '.rb').sub(/_spec\z/, '')
    camel = base.split(/[^0-9A-Za-z]+/).map { |s| s.capitalize }.join
    camel.empty? ? 'UnknownSpec' : "#{camel}Spec"
  end

  def normalize(locator)
    key = locator.keys.first
    val = locator.values.first
    case key.to_sym
    when :id then [:id, val]
    when :xpath then [:xpath, val]
    when :accessibility_id then [:accessibility_id, val]
    else [key.to_sym, val]
    end
  end

  def safe_call
    yield
  rescue StandardError
    nil
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end




