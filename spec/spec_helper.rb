# path: spec/spec_helper.rb
$stdout.sync = true

require 'appium_lib'
require_relative '../config/capabilities'
require 'allure-rspec'
require 'fileutils'
require 'base64'
require 'open3'

# ==============================
# Allure configuration
# ==============================
Allure.configure do |c|
  c.results_directory = 'reports/allure-results'
  c.clean_results_directory = true
end

# Allows disabling screen recording: RECORD_VIDEO=0 bundle exec rspec
RECORD_VIDEO = ENV.fetch('RECORD_VIDEO', '1') == '1'

# ==============================
# RSpec configuration
# ==============================
RSpec.configure do |config|
  # --- Formatters ---
  config.add_formatter 'AllureRspecFormatter'
  config.add_formatter 'documentation'
  config.output_stream = $stdout
  config.error_stream  = $stderr

  # --- Appium driver setup ---
  def driver_config
    { caps: CONFIG, appium_lib: { server_url: 'http://127.0.0.1:4723' } }
  end

  config.before(:suite) do
    $driver = Appium::Driver.new(driver_config, true).start_driver
    Appium.promote_appium_methods Object
  end

  config.after(:suite) do
    $driver.quit rescue nil if $driver&.session_id
  end

  # ==============================
  # Screenshot handling (refactored)
  # ==============================
  #
  # Screenshots are now handled by BasePage/ReportsHelpers#save_SCREENSHOT,
  # which stores them in-memory and attaches directly to Allure.
  #
  # Therefore, all code that manually creates "screenshots/" folders was removed.
  #
  # If you still want to capture automatically on failure,
  # use @page.save_SCREENSHOT instead of driver.save_screenshot.

  config.after(:each) do |example|
    # Optional automatic screenshot capture on test failure
    if example.exception && defined?(@page)
      begin
        @page.save_SCREENSHOT(name: "FAILED - #{example.description}")
      rescue => e
        warn "[Allure] Screenshot capture failed: #{e.message}"
      end
    end

    # Terminate app after each test (clean state)
    if $driver&.session_id
      pkg = CONFIG[:appPackage] rescue nil
      $driver.terminate_app(pkg) rescue nil if pkg
    end
  end

  # ==============================
  # Add custom CSS to Allure reports
  # ==============================
  def add_allure_custom_style
    css_dir = File.join('reports', 'allure-report')
    css_file = File.join(css_dir, 'styles.css')
    return warn '[WARN] Allure report not found' unless File.exist?(css_file)

    css_code = <<~CSS
      img {
        max-width: 30% !important;
        height: auto !important;
        border-radius: 8px;
        box-shadow: 0 0 10px rgba(0,0,0,0.25);
        margin: 12px auto;
        display: block;
      }
      .attachment__content {
        display: flex;
        justify-content: center;
        align-items: center;
        background-color: #f3f3f3;
        padding: 12px;
        border-radius: 10px;
      }
    CSS
    File.open(css_file, 'a') { |f| f.puts css_code }
  end

  # ==============================
  # Video recording (via Appium)
  # ==============================
  config.before(:each) do |_example|
    next unless RECORD_VIDEO
    begin
      if $driver.respond_to?(:start_recording_screen)
        $driver.start_recording_screen
      end
    rescue => e
      warn "[WARN] start_recording_screen failed: #{e.class} - #{e.message}"
    end
  end

  config.after(:each) do |example|
    next unless RECORD_VIDEO
    begin
      if $driver.respond_to?(:stop_recording_screen)
        base64_video = $driver.stop_recording_screen rescue nil

        # Only attach videos for failed tests
        if example.exception && base64_video && !base64_video.empty?
          video_dir  = File.join('reports', 'videos')
          FileUtils.mkdir_p(video_dir) rescue nil

          safe_name  = example.full_description.gsub(/[^\w\-]+/, '_')[0..60]
          video_path = File.join(video_dir, "#{safe_name}_#{Time.now.strftime('%Y%m%d-%H%M%S')}.mp4")

          File.open(video_path, 'wb') { |f| f.write(Base64.decode64(base64_video)) }

          # Compress/scale video for size reduction
          system("ffmpeg -y -i \"#{video_path}\" -vf scale=540:960 \"#{video_path}.tmp.mp4\" > /dev/null 2>&1")
          if File.exist?("#{video_path}.tmp.mp4")
            FileUtils.mv("#{video_path}.tmp.mp4", video_path)
          end

          if File.exist?(video_path) && File.size?(video_path)
            Allure.add_attachment(
              name: "Video - #{example.description}",
              source: File.open(video_path, 'rb'),
              type: 'video/mp4',
              test_case: true
            )
          end
        end
      end
    rescue => e
      warn "[ERROR] stop_recording_screen failed: #{e.class} - #{e.message}"
    end
  end
  # --- End of video recording ---

  # ==============================
  # Capture STDOUT/STDERR and attach to Allure
  # ==============================
  config.around(:each) do |example|
    require 'stringio'
    old_stdout, old_stderr = $stdout, $stderr
    buffer = StringIO.new

    writer = Class.new do
      def initialize(console, capture)
        @console, @capture = console, capture
      end
      def write(str)
        @console.write(str)
        @capture.write(str)
      end
      def flush
        @console.flush
        @capture.flush
      end
    end

    $stdout = writer.new(old_stdout, buffer)
    $stderr = writer.new(old_stderr, buffer)

    begin
      example.run
    ensure
      $stdout, $stderr = old_stdout, old_stderr
      output = buffer.string
      next if output.strip.empty?

      log_dir = File.join('reports', 'logs')
      FileUtils.mkdir_p(log_dir) rescue nil
      safe_name = example.full_description.gsub(/[^\w\-]+/, '_')[0..60]
      log_file = File.join(log_dir, "#{safe_name}_#{Time.now.strftime('%Y%m%d-%H%M%S')}.log")
      File.write(log_file, output)

      Allure.add_attachment(
        name: 'Console Output',
        source: File.open(log_file, 'rb'),
        type: Allure::ContentType::TXT,
        test_case: true
      ) rescue nil
    end
  end
end
