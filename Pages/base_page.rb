# path: pages/base_page.rb
require 'fileutils'
require 'base64'
require 'set'

class BasePage
  attr_reader :driver

  def initialize(driver = $driver)
    @driver = driver
  end

  # Screenshot state
  def remember_last_action(sym)
    @__last_action = sym.to_s
  end

  def last_action_name
    @__last_action || 'unknown_action'
  end

  def next_screenshot_index
    Thread.current[:screenshot_index] = (Thread.current[:screenshot_index] || 0) + 1
  end

  # Waits & element queries
  def wait_until(timeout: 3.0, interval: 0.10)
    deadline = monotonic_now + timeout.to_f
    loop do
      return true if yield
      break if monotonic_now >= deadline
      sleep interval
    end
    false
  end

  # Always returns an array
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

  # Waits for element; optionally validates with a block
  def try_find(locator, timeout: 3.0, interval: 0.10)
    el = nil
    ok = wait_until(timeout: timeout, interval: interval) do
      el = find!(locator) rescue nil
      el && (!block_given? || yield(el))
    end
    ok ? el : nil
  end

  def click(locator, timeout: 3.0)
    el = try_find(locator, timeout: timeout) { |e| interactable?(e) }
    raise "No clickable: #{locator.inspect}" unless el
    el.click
    true
  end

  def texts_of(locator, limit: nil, retries: 2)
    list = []
    attempts = 0
    begin
      list = elements(locator).map { |e| e.text rescue '' }
    rescue Selenium::WebDriver::Error::StaleElementReferenceError, Selenium::WebDriver::Error::UnknownError
      attempts += 1
      retry if attempts <= retries
    end
    list = list.first(limit) if limit
    list
  end

  # Screenshots
  # path: pages/base_page.rb
  # path: pages/base_page.rb
  require 'base64'
  require 'tempfile'

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

    # === Adjuntar a Allure de forma segura (archivo temporal binario) ===
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
        warn "[Allure] No se pudo adjuntar screenshot #{path}: #{e.class}: #{e.message}"
      end
    end

    path
  end






  # (opcional) helper para adjuntar texto/logs cuando lo necesites
  def attach_text_to_allure(name, text)
    Allure.add_attachment(
      name: name.to_s,
      source: text.to_s,
      type: Allure::ContentType::TXT,
      test_case: true
    )
  rescue StandardError
    # silencioso
  end


  # UI idle detection
  def ui_loading_present?
    xpaths = [
      '//android.widget.ProgressBar',
      '//*[@resource-id="android:id/progress"]',
      '//*[contains(@text,"Cargando")]',
      '//*[contains(@text,"loading")]',
      '//*[contains(@content-desc,"Cargando")]',
      '//*[contains(@content-desc,"loading")]'
    ]
    xpaths.any? { |xp| driver.find_elements(xpath: xp)&.any? }
  rescue StandardError
    false
  end

  def wait_for_ui_idle(timeout: 5.0, stable_duration: 0.4, poll: 0.08)
    deadline     = monotonic_now + timeout
    prev_sig     = nil
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

  # Scroll & DOM change helpers
  def page_signature
    driver.page_source.hash
  rescue StandardError
    monotonic_now.to_i
  end

  def scroll_down(percent: 0.95)
    size = driver.manage.window.size
    top  = (size.height * 0.20).to_i
    h    = (size.height * 0.60).to_i
    driver.execute_script(
      'mobile: scrollGesture',
      { 'left' => 0, 'top' => top, 'width' => size.width, 'height' => h,
        'direction' => 'down', 'percent' => percent }
    )
    true
  rescue StandardError
    begin
      script = 'new UiScrollable(new UiSelector().scrollable(true).instance(0)).scrollForward()'
      driver.find_element(:uiautomator, script)
      true
    rescue StandardError
      false
    end
  end

  def wait_dom_change_or_new(card_xpath:, old_sig:, old_count:, timeout: 1.4, poll: 0.05)
    deadline = monotonic_now + timeout
    while monotonic_now < deadline
      sig   = page_signature
      count = driver.find_elements(xpath: card_xpath).size
      return :new_items if count > old_count
      return :changed   if sig != old_sig
      sleep poll
    end
    :no_change
  end

  # Generic collection with early exit
  def first_n_by_scroll(card_xpath:, extractor:, max:, max_scrolls: 3)
    productos, precios = [], []
    seen_keys = Set.new

    consecutive_nochange = 0
    pushes_total = 0

    max_scrolls.times do
      driver.find_elements(xpath: card_xpath).each do |card|
        t = safe_call { extractor.call(card) }
        next unless t
        name, price, key = t
        key ||= "#{name}|#{price}"
        next if seen_keys.include?(key)

        productos << name
        precios  << price
        seen_keys << key
        return [productos.first(max), precios.first(max)] if productos.size >= max
      end

      before_keys = snapshot_keys(card_xpath, extractor)

      old_sig   = page_signature
      old_count = driver.find_elements(xpath: card_xpath).size
      break unless scroll_down(percent: 0.96)

      change = wait_dom_change_or_new(card_xpath: card_xpath, old_sig: old_sig, old_count: old_count, timeout: 2.0)
      sleep 0.08 if change != :no_change

      after_keys = snapshot_keys(card_xpath, extractor)
      consecutive_nochange = (change == :no_change || after_keys == before_keys) ? consecutive_nochange + 1 : 0

      if consecutive_nochange > 0
        pushes_this_round = 0
        while pushes_this_round < 2 && pushes_total < 4
          pushes_this_round += 1
          pushes_total += 1
          break unless scroll_down(percent: 0.985)
          _ = wait_dom_change_or_new(card_xpath: card_xpath,
                                     old_sig: page_signature,
                                     old_count: driver.find_elements(xpath: card_xpath).size,
                                     timeout: 1.0)
          sleep 0.06
          pushed_keys = snapshot_keys(card_xpath, extractor)
          break unless pushed_keys == after_keys
        end
      end

      break if consecutive_nochange >= 2
    end

    [productos.first(max), precios.first(max)]
  end

  # Search/scroll helpers
  def scroll_to_text(text, max_swipes: 16, container_uiautomator: nil)
    uis = []
    if container_uiautomator
      uis << "new UiScrollable(#{container_uiautomator}).scrollTextIntoView(\"#{text}\")"
      uis << "new UiScrollable(#{container_uiautomator}).getChildByText(new UiSelector().className(\"android.widget.TextView\"), \"#{text}\")"
      uis << "new UiScrollable(#{container_uiautomator}).scrollIntoView(new UiSelector().textContains(\"#{text}\"))"
    end
    0.upto(3) do |i|
      uis << "new UiScrollable(new UiSelector().scrollable(true).instance(#{i})).scrollTextIntoView(\"#{text}\")"
      uis << "new UiScrollable(new UiSelector().scrollable(true).instance(#{i})).scrollIntoView(new UiSelector().textContains(\"#{text}\"))"
    end
    uis.each { |script| return true if safe_call { driver.find_element(:uiautomator, script) } }

    xp = "//*[contains(@text, \"#{text}\")]"
    return true if driver.find_elements(xpath: xp).any?

    max_swipes.times do
      break unless scroll_down(percent: 0.96)
      sleep 0.05
      return true if driver.find_elements(xpath: xp).any?
    end
    false
  end

  def scroll_until(locator, max_swipes: 16, container_uiautomator: nil)
    if container_uiautomator
      ui = "new UiScrollable(#{container_uiautomator}).scrollIntoView(new UiSelector().xpath(\"#{normalize(locator)[1]}\"))"
      return true if safe_call { driver.find_element(:uiautomator, ui) }
    end
    return true if present?(locator)
    max_swipes.times do
      break unless scroll_down(percent: 1)
      sleep 0.1
      return true if present?(locator)
    end
    false
  end

  # Element utilities
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

  # Title heuristic (filters ratings/badges/numerics)
  def looks_like_title?(text)
    t = (text || '').strip
    return false if t.empty?

    td = t.downcase
    banned = %w[
      gratis envío env\u00eo llega mañana hoy cuotas meses oferta % off descuento prime full seller vendedor
      tienda oficial oficial store patrocinado anuncio visit marca brand garantía vendidos vendido
      opiniones opinión reseñas reseña review reviews calificación rating puntos estrella estrellas
    ]
    return false if banned.any? { |w| td.include?(w) }

    return false if t =~ /\A[\s\-\+\|\.,\d]+\z/
    return false if t =~ /\b\d(?:\.\d)?\s*\|\s*\+\d/
    return false if t =~ /★|⭐|☆/

    has_letters = t.count('A-Za-zÁÉÍÓÚáéíóúÜüÑñ') >= 3
    return false unless has_letters
    return false if t.length < 8
    t.split.size >= 2
  end

  # Bounds helpers
  def bounds_rect(el)
    b = safe_call { el.attribute('bounds') }
    return [0,0,0,0] unless b && b =~ /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/
    [$1.to_i, $2.to_i, $3.to_i, $4.to_i]
  end

  def center_y(el)
    r = bounds_rect(el)
    (r[1] + r[3]) / 2.0
  end

  private

  # Private utilities
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

  # Short, non-blocking settle before taking a screenshot
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
      # Never block screenshot flow on settle errors
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


  # Derive current test class name (RSpec)
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
    when :id               then [:id, val]
    when :xpath            then [:xpath, val]
    when :accessibility_id then [:accessibility_id, val]
    else [key.to_sym, val]
    end
  end

  def safe_call
    yield
  rescue StandardError
    nil
  end

  # Monotonic clock for time-sensitive waits
  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
