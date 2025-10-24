# path: pages/helpers/reports_helpers.rb
# ======================================
# ReportsHelpers
# Provides screenshot and Allure attachment utilities.
# ======================================

require 'base64'
require 'tempfile'

module ReportsHelpers
  # Take a screenshot and attach it to Allure report (in-memory, no local file)
  def save_SCREENSHOT(name: nil, folder: nil, wait_for_idle: true, settle_ms: 180)
    wait_for_ui_idle if wait_for_idle
    base = (name && !name.to_s.empty?) ? name.to_s : last_action_name

    png_data = nil
    drv = driver
    if drv.respond_to?(:screenshot_as)
      png_data = Base64.decode64(drv.screenshot_as(:base64))
    elsif drv.respond_to?(:save_screenshot)
      Tempfile.create(["screenshot_", ".png"]) do |tmp|
        drv.save_screenshot(tmp.path)
        png_data = File.binread(tmp.path)
      end
    elsif drv.respond_to?(:driver) && drv.driver.respond_to?(:screenshot_as)
      png_data = Base64.decode64(drv.driver.screenshot_as(:base64))
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
    nil
  end

  # Attach plain text to Allure report
  def attach_text_to_allure(name, text)
    Allure.add_attachment(
      name: name.to_s,
      source: text.to_s,
      type: Allure::ContentType::TXT,
      test_case: true
    )
  rescue StandardError
  end
end
