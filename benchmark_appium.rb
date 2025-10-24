# path: benchmark_appium.rb
# ======================================================
# Appium Benchmark Helper
# Measures performance of find_element, click, and scroll.
# Helps identify if latency comes from Appium, the emulator, or Ruby itself.
# ======================================================

require 'appium_lib'

CONFIG = {
  caps: {
    platformName: 'Android',
    deviceName: 'emulator-5554', # adjust if needed
    appPackage: 'com.mercadolibre',
    appActivity: 'com.mercadolibre.splash.SplashActivity',
    automationName: 'UiAutomator2',
    newCommandTimeout: 180
  },
  appium_lib: {
    server_url: 'http://127.0.0.1:4723'
  }
}

driver = Appium::Driver.new(CONFIG, true).start_driver
Appium.promote_appium_methods Object

puts "\n🚀 Starting Appium benchmark..."
puts "Device: #{driver.device_time rescue 'unknown'}"
puts "Appium version: #{driver.capabilities['automationName']}"

# Helper for timing
def measure(label)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  puts format("⏱ %-25s: %.3f s", label, elapsed)
  elapsed
end

# Benchmark suite
results = {}

# 1️⃣ Find element test
results[:find] = measure("100x find_elements") do
  100.times { driver.find_elements(:xpath, "//android.widget.FrameLayout") }
end

# 2️⃣ Click test (using a safe fallback)
test_button = driver.find_elements(:xpath, "//android.widget.Button").first
if test_button
  results[:click] = measure("20x click") do
    20.times { test_button.click rescue nil }
  end
else
  puts "⚠️ No button found to click — skipping click test."
end

# 3️⃣ Scroll test
size = driver.manage.window.size
scroll_args = {
  'left' => 0, 'top' => (size.height * 0.2).to_i,
  'width' => size.width, 'height' => (size.height * 0.6).to_i,
  'direction' => 'down', 'percent' => 0.7
}
results[:scroll] = measure("10x scrollGesture") do
  10.times { driver.execute_script('mobile: scrollGesture', scroll_args) rescue nil }
end

# 4️⃣ Page source test (DOM read cost)
results[:page_source] = measure("5x page_source") do
  5.times { driver.page_source rescue nil }
end

# Summary
puts "\n📊 Benchmark Summary:"
results.each { |k, v| puts format("• %-15s: %.3f s", k, v) }

puts "\n💡 Recommendations:"
if results[:find] > 10
  puts "- Your Appium connection seems slow (>10 s for 100 finds). Check VPN, proxies, or CPU load."
end
if results[:click] && results[:click] > 5
  puts "- Clicks are slower than expected (>5 s total). The UI may have overlays or GPU animations."
end
if results[:page_source] > 3
  puts "- DOM reads (page_source) are expensive. Minimize usage inside loops."
end
if results[:scroll] > 3
  puts "- Scroll gestures are taking too long. Try reducing scroll percent or disabling animations."
end

puts "\n✅ Done. Close the emulator or press Ctrl+C when ready."
driver.quit rescue nil
