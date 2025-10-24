# path: pages/helpers/wait_helpers.rb
# ======================================
# WaitHelpers
# Provides generic polling and UI idle wait mechanisms.
# ======================================

module WaitHelpers
  # Adaptive polling wait
  def wait_until(timeout: 2.0, interval: 0.05)
    deadline = monotonic_now + timeout.to_f
    while monotonic_now < deadline
      return true if yield
      sleep interval
    end
    false
  end

  # Wait until UI becomes visually stable (no loading, no DOM change)
  def wait_for_ui_idle(timeout: 3.0, stable_duration: 0.25, poll: 0.05)
    deadline = monotonic_now + timeout
    prev_sig, stable_count = nil, 0
    while monotonic_now < deadline
      sig = page_signature
      if !ui_loading_present? && sig == prev_sig
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

  # Detect loading indicators (progress bars, spinners, etc.)
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
end
