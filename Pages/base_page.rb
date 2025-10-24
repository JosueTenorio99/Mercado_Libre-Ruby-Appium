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

  # Espera rápida con polling adaptativo
  def wait_until(timeout: 2.0, interval: 0.05)
    deadline = monotonic_now + timeout.to_f
    cur_interval = interval
    loop do
      return true if yield
      break if monotonic_now >= deadline
      sleep cur_interval
      cur_interval = [cur_interval * 1.5, 0.25].min
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

  def try_find(locator, timeout: 1.5, interval: 0.05)
    el = nil
    ok = wait_until(timeout: timeout, interval: interval) do
      el = find!(locator) rescue nil
      el && (!block_given? || yield(el))
    end
    ok ? el : nil
  end

  # Click optimizado: sin sleeps fijos, con detección reactiva
  def click(locator, timeout: 3.0, retries: 1, smart: false, success: nil)
    el = try_find(locator, timeout: timeout) { |e| interactable?(e) }
    raise "Not clickable: #{locator.inspect}" unless el

    driver.hide_keyboard rescue nil
    old_sig = page_signature
    succeeded = false

    toggle_like = ->(e) {
      %w[checked selected].any? { |a| (e.attribute(a) rescue 'false') == 'true' }
    }

    (retries + 1).times do
      begin
        el.click
      rescue Selenium::WebDriver::Error::ElementClickInterceptedError,
        Selenium::WebDriver::Error::StaleElementReferenceError
        el = try_find(locator, timeout: 0.6) { |e| interactable?(e) }
        el&.click
      end

      if smart
        succeeded = wait_until(timeout: 1.2, interval: 0.05) do
          (success && safe_call { success.call }) ||
            toggle_like.call(el) ||
            page_signature != old_sig
        end
        break if succeeded
      else
        return true
      end
    end

    # Fallback nativo rápido
    if smart && !succeeded
      begin
        ctx = driver.respond_to?(:current_context) ? driver.current_context.to_s : 'NATIVE_APP'
        unless ctx.include?('WEBVIEW')
          l, t, r, b = bounds_rect(el)
          x, y = [(l + r) / 2, (t + b) / 2]
          driver.execute_script('mobile: clickGesture', { x: x, y: y })
          succeeded = wait_until(timeout: 1.2, interval: 0.05) do
            (success && safe_call { success.call }) ||
              page_signature != old_sig
          end
        end
      rescue StandardError
      end
    end

    raise "Failed to click #{locator.inspect}" unless succeeded || !smart
    true
  end

  def save_SCREENSHOT(name: nil, folder: nil, wait_for_idle: true, settle_ms: 120)
    settle_for_screenshot(settle_ms: settle_ms) if wait_for_idle
    base = (name && !name.to_s.empty?) ? name.to_s : last_action_name

    drv = driver
    png_data = if drv.respond_to?(:screenshot_as)
                 Base64.decode64(drv.screenshot_as(:base64))
               elsif drv.respond_to?(:save_screenshot)
                 Tempfile.create(["shot", ".png"]) do |tmp|
                   drv.save_screenshot(tmp.path)
                   File.binread(tmp.path)
                 end
               elsif drv.respond_to?(:driver) && drv.driver.respond_to?(:screenshot_as)
                 Base64.decode64(drv.driver.screenshot_as(:base64))
               end

    if defined?(Allure) && png_data
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
    end
    nil
  rescue => e
    warn "[Allure] Screenshot failed: #{e.message}"
  end

  def wait_for_ui_idle(timeout: 3.0, stable_duration: 0.25, poll: 0.05)
    deadline = monotonic_now + timeout
    prev_sig = nil
    stable_count = 0

    while monotonic_now < deadline
      sig = page_signature
      if !ui_loading_present? && prev_sig == sig
        stable_count += 1
        return true if stable_count >= (stable_duration / poll)
      else
        stable_count = 0
      end
      prev_sig = sig
      sleep poll
    end
    false
  end

  def scroll_down(percent: 0.95, column_index: 0)
    size = driver.manage.window.size
    top  = (size.height * 0.20).to_i
    h    = (size.height * 0.60).to_i
    driver.execute_script(
      'mobile: scrollGesture',
      { 'left' => 0, 'top' => top, 'width' => size.width, 'height' => h,
        'direction' => 'down', 'percent' => percent }
    )
    true
  rescue
    script = "new UiScrollable(new UiSelector().scrollable(true).instance(#{column_index})).scrollForward()"
    safe_call { driver.find_element(:uiautomator, script) }
    false
  end

  def scroll_to_text(text, max_swipes: 10, column_index: 0)
    xp = "//*[contains(@text, \"#{text}\")]"
    return true if driver.find_elements(xpath: xp).any?

    max_swipes.times do
      break unless scroll_down(percent: 0.96, column_index: column_index)
      return true if driver.find_elements(xpath: xp).any?
    end
    false
  end

  def scroll_until(locator, max_swipes: 10, column_index: 0)
    return true if present?(locator)
    max_swipes.times do
      break unless scroll_down(percent: 1, column_index: column_index)
      return true if present?(locator)
    end
    false
  end

  private

  def interactable?(el)
    (el.displayed? rescue true) && (el.enabled? rescue true)
  end

  def safe_call
    yield
  rescue StandardError
    nil
  end

  def normalize(locator)
    key = locator.keys.first
    val = locator.values.first
    [key.to_sym, val]
  end

  def bounds_rect(el)
    b = safe_call { el.attribute('bounds') }
    b =~ /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/ ? [$1.to_i, $2.to_i, $3.to_i, $4.to_i] : [0, 0, 0, 0]
  end

  def page_signature
    driver.page_source.hash
  rescue
    monotonic_now.to_i
  end

  def ui_loading_present?
    %w[
      //android.widget.ProgressBar
      //*[@resource-id="android:id/progress"]
      //*[contains(@text,"Loading")]
      //*[contains(@content-desc,"Loading")]
    ].any? { |xp| driver.find_elements(xpath: xp)&.any? }
  rescue
    false
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def settle_for_screenshot(settle_ms:)
    ctx = driver.respond_to?(:current_context) ? driver.current_context.to_s : ''
    if ctx.include?('WEBVIEW')
      driver.execute_script('return document.readyState') rescue nil
      driver.execute_async_script(<<~JS) rescue nil
        var cb = arguments[arguments.length - 1];
        requestAnimationFrame(()=>requestAnimationFrame(cb));
      JS
    else
      sleep([settle_ms, 150].min / 1000.0)
    end
  rescue StandardError
  end
end
