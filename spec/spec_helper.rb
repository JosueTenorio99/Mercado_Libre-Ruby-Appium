# path: spec/spec_helper.rb
$stdout.sync = true

require 'appium_lib'
require_relative '../config/capabilities'
require 'allure-rspec'
require 'fileutils'
require 'base64'
require 'open3'

Allure.configure do |c|
  c.results_directory = 'reports/allure-results'
  c.clean_results_directory = true
end

RSpec.configure do |config|
  # Allure report formatter
  config.add_formatter 'AllureRspecFormatter'

  # Console output formatter (you can use 'progress' for dots)
  config.add_formatter 'documentation'

  # Force RSpec to print to real console
  config.output_stream = $stdout
  config.error_stream  = $stderr
end

def driver_config
  { caps: CONFIG, appium_lib: { server_url: 'http://127.0.0.1:4723' } }
end

def current_test_class_name_from(example)
  if example.example_group.respond_to?(:described_class) && example.example_group.described_class
    example.example_group.described_class.name
  else
    file = example.file_path rescue nil
    return 'UnknownSpec' unless file
    base = File.basename(file, '.rb').sub(/_spec\z/, '')
    camel = base.split(/[^0-9A-Za-z]+/).map { |s| s.capitalize }.join
    camel.empty? ? 'UnknownSpec' : "#{camel}Spec"
  end
end

def save_failure_screenshot(driver, example)
  klass = current_test_class_name_from(example)
  folder = File.join('screenshots', klass)
  FileUtils.mkdir_p(folder) rescue nil

  Thread.current[:screenshot_index] = (Thread.current[:screenshot_index] || 0) + 1
  prefix    = format('%02d', Thread.current[:screenshot_index])
  timestamp = Time.now.strftime('%Y%m%d-%H%M%S-%L')
  path      = File.join(folder, "#{prefix}_failure_#{timestamp}.png")

  if driver.respond_to?(:save_screenshot)
    driver.save_screenshot(path)
  elsif driver.respond_to?(:screenshot_as)
    File.open(path, 'wb') { |f| f.write(Base64.decode64(driver.screenshot_as(:base64))) }
  elsif driver.respond_to?(:driver) && driver.driver.respond_to?(:save_screenshot)
    driver.driver.save_screenshot(path)
  end
rescue
end

RSpec.configure do |config|
  # === Appium driver setup ===
  config.before(:suite) do
    $driver = Appium::Driver.new(driver_config, true).start_driver
    Appium.promote_appium_methods Object
  end

  config.before(:each) do
    Thread.current[:screenshot_index] = 0
  end

  # === Screenshot on failure ===
  config.after(:each) do |example|
    if example.exception && $driver&.session_id
      save_failure_screenshot($driver, example)
    end

    if $driver&.session_id
      pkg = CONFIG[:appPackage] rescue nil
      $driver.terminate_app(pkg) rescue nil if pkg
      $driver.manage.timeouts.implicit_wait = 0 rescue nil
    end
  end

  # === Quit driver after suite ===
  config.after(:suite) do
    if $driver&.session_id
      $driver.quit rescue nil
    end
  end

  # === Add Allure custom CSS ===
  def add_allure_custom_style
    css_dir = File.join('reports', 'allure-report')
    css_file = File.join(css_dir, 'styles.css')

    unless File.exist?(css_file)
      warn '[WARN] Allure report not found, run: allure generate or allure serve'
      return
    end

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

  # === Video recording with adb and Allure ===
  config.before(:each) do |example|
    begin
      @video_dir = File.join('reports', 'videos')
      FileUtils.mkdir_p(@video_dir) rescue nil

      safe_name = example.full_description.gsub(/[^\w\-]+/, '_')[0..60]
      @video_file = File.join(@video_dir, "#{safe_name}_#{Time.now.strftime('%Y%m%d-%H%M%S')}.mp4")

      @adb_pid = spawn('adb shell screenrecord --size 540x960 /sdcard/test_record.mp4', out: '/dev/null', err: '/dev/null')
      sleep 1
    rescue => e
      warn "[WARN] Could not start video recording: #{e.class} - #{e.message}"
    end
  end

  config.after(:each) do |example|
    begin
      if @adb_pid
        Process.kill('INT', @adb_pid) rescue nil
        Process.wait(@adb_pid) rescue nil
        sleep 1

        system("adb pull /sdcard/test_record.mp4 \"#{@video_file}\"")
        system('adb shell rm /sdcard/test_record.mp4')

        if File.exist?(@video_file)
          Allure.add_attachment(
            name: "Video - #{example.description}",
            source: File.open(@video_file, 'rb'),
            type: Allure::ContentType::WEBM,
            test_case: true
          )
        else
          warn '[WARN] Video file not found to attach'
        end
      end
    rescue => e
      warn "[ERROR] Video processing failed: #{e.class} - #{e.message}"
    end
  end
  # === End of video recording ===

  # === Capture STDOUT and STDERR, and attach to Allure ===
  config.around(:each) do |example|
    require 'stringio'

    old_stdout = $stdout
    old_stderr = $stderr
    buffer = StringIO.new

    writer_class = Class.new do
      def initialize(console, capture)
        @console = console
        @capture = capture
      end

      def write(str)
        @console.write(str)
        @capture.write(str)
        @console.flush
        @capture.flush
      end

      def flush
        @console.flush
        @capture.flush
      end
    end

    $stdout = writer_class.new(old_stdout, buffer)
    $stderr = writer_class.new(old_stderr, buffer)

    begin
      example.run
    ensure
      $stdout = old_stdout
      $stderr = old_stderr
      output = buffer.string

      log_dir = File.join('reports', 'logs')
      FileUtils.mkdir_p(log_dir) rescue nil

      safe_name = example.full_description.gsub(/[^\w\-]+/, '_')[0..60]
      log_file = File.join(log_dir, "#{safe_name}_#{Time.now.strftime('%Y%m%d-%H%M%S')}.log")
      File.write(log_file, output)

      if defined?(Allure) && !output.strip.empty?
        begin
          Allure.add_attachment(
            name: 'Console Output',
            source: File.open(log_file, 'rb'),
            type: Allure::ContentType::TXT,
            test_case: true
          )
        rescue StandardError => e
          old_stderr.write("[Allure] Could not attach console output: #{e.class} #{e.message}\n")
        end
      end
    end
  end
  # === End of STDOUT/STDERR capture ===
end
