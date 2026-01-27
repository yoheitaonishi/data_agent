require "cgi"
require "json"

class Obic7ScraperService
  class ScrapingError < StandardError; end

  def initialize
    @driver = nil
    @wait = nil
    @agentic_job_id = nil
  end

  def scrape_obic7_data(agentic_job_id: nil)
    @agentic_job_id = agentic_job_id
    setup_driver
    navigate_to_obic7
    login
    { success: true, message: "Successfully logged in to OBIC7" }
  ensure
    cleanup_driver
  end

  def login_and_export_master_data(agentic_job_id: nil)
    @agentic_job_id = agentic_job_id
    setup_driver
    navigate_to_obic7
    login
    export_master_data
    { success: true, message: "Successfully exported master data from OBIC7" }
  ensure
    cleanup_driver
  end

  private

  def setup_driver
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    # options.add_argument("--headless=new")  # Commented out for development
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-blink-features=AutomationControlled")

    @driver = Selenium::WebDriver.for :chrome, options: options
    @wait = Selenium::WebDriver::Wait.new(timeout: 15)
  end

  def cleanup_driver
    @driver&.quit
  end

  def navigate_to_obic7
    obic7_url = "https://metawn.obic7.obicnet.ne.jp/WebMenu30/Pages/Common/MainFrame.aspx"

    Rails.logger.info "Navigating to OBIC7: #{obic7_url}"
    @driver.get(obic7_url)

    # Wait for page to load
    @wait.until { @driver.find_element(tag_name: "body") }
    Rails.logger.info "OBIC7 page loaded successfully"
  rescue => e
    Rails.logger.error "Error navigating to OBIC7: #{e.message}"
    Rails.logger.error "Current URL: #{@driver.current_url}"
    Rails.logger.error "Page source: #{@driver.page_source[0..500]}"
    raise
  end

  def login
    Rails.logger.info "Starting OBIC7 login process..."

    begin
      # Check for iframes and switch if necessary
      Rails.logger.info "Checking for iframes..."
      iframes = @driver.find_elements(tag_name: "iframe")
      Rails.logger.info "Found #{iframes.length} iframe(s)"

      if iframes.any?
        Rails.logger.info "Switching to first iframe..."
        @driver.switch_to.frame(iframes.first)
        Rails.logger.info "Switched to iframe"
      end

      # Wait a bit for iframe content to load
      sleep 2

      # Try to find input fields with various selectors
      Rails.logger.info "Looking for ID field..."
      id_field = nil
      id_selectors = [
        { type: :name, value: "txtUserId" },
        { type: :id, value: "txtUserId" },
        { type: :css, value: "input[type='text']" },
        { type: :css, value: "input[name*='User']" },
        { type: :css, value: "input[name*='user']" },
        { type: :css, value: "input[name*='Id']" },
        { type: :css, value: "input[name*='id']" }
      ]

      id_selectors.each do |selector|
        begin
          Rails.logger.info "Trying selector: #{selector[:type]} = #{selector[:value]}"
          id_field = @driver.find_element(selector[:type], selector[:value])
          if id_field
            Rails.logger.info "ID field found with #{selector[:type]}: #{selector[:value]}"
            break
          end
        rescue Selenium::WebDriver::Error::NoSuchElementError
          next
        end
      end

      unless id_field
        Rails.logger.error "Could not find ID field. Available input fields:"
        inputs = @driver.find_elements(tag_name: "input")
        inputs.each_with_index do |input, i|
          Rails.logger.error "Input #{i}: type=#{input.attribute('type')}, name=#{input.attribute('name')}, id=#{input.attribute('id')}"
        end
        raise "ID field not found"
      end

      Rails.logger.info "Entering ID..."
      id_field.send_keys(ENV.fetch("OBIC7_ID"))

      # Find password field
      Rails.logger.info "Looking for password field..."
      password_field = nil
      password_selectors = [
        { type: :name, value: "txtPassword" },
        { type: :id, value: "txtPassword" },
        { type: :css, value: "input[type='password']" },
        { type: :css, value: "input[name*='Password']" },
        { type: :css, value: "input[name*='password']" }
      ]

      password_selectors.each do |selector|
        begin
          Rails.logger.info "Trying selector: #{selector[:type]} = #{selector[:value]}"
          password_field = @driver.find_element(selector[:type], selector[:value])
          if password_field
            Rails.logger.info "Password field found with #{selector[:type]}: #{selector[:value]}"
            break
          end
        rescue Selenium::WebDriver::Error::NoSuchElementError
          next
        end
      end

      unless password_field
        raise "Password field not found"
      end

      Rails.logger.info "Entering password..."
      password_field.send_keys(ENV.fetch("OBIC7_PASSWORD"))

      # Submit the form
      Rails.logger.info "Submitting login form..."
      begin
        # Try to find and click login button
        login_button = @driver.find_element(id: "btnLogin")
        safe_click(login_button)
        Rails.logger.info "Login button clicked successfully"
      rescue Selenium::WebDriver::Error::NoSuchElementError => e
        Rails.logger.warn "Login button not found by id, trying other selectors: #{e.message}"
        begin
          login_button = @driver.find_element(css: "input[type='submit']")
          safe_click(login_button)
          Rails.logger.info "Submit button clicked successfully"
        rescue => e2
          Rails.logger.warn "Submit button click failed, trying form submit: #{e2.message}"
          form = @driver.find_element(tag_name: "form")
          form.submit
          Rails.logger.info "Form submitted successfully"
        end
      end

      # Switch back to default content if we were in an iframe
      @driver.switch_to.default_content if iframes.any?

      # Wait for login to complete
      Rails.logger.info "Waiting for login to complete..."
      sleep 3 # Give time for page to transition
      Rails.logger.info "Login completed. Current URL: #{@driver.current_url}"

      # Add a sleep to keep browser open for manual inspection
      sleep 5

    rescue => e
      Rails.logger.error "Error during OBIC7 login: #{e.message}"
      Rails.logger.error "Current URL: #{@driver.current_url}"
      Rails.logger.error "Page source: #{@driver.page_source[0..2000]}"
      raise
    end
  end

  def export_master_data
    Rails.logger.info "Starting master data export process..."

    begin
      # Navigate to data output page
      data_output_url = "https://metawn.obic7.obicnet.ne.jp/IOWeb30Sat/Pages/Input/DataOutput.aspx?cgid=c641f899-02df-d789-c8b9-82559e224560&gid=ddb2bb3c-64f0-4ce3-a4a9-7c3687bed2c8&pid=ZAE0000092"
      Rails.logger.info "Navigating to data output page: #{data_output_url}"
      @driver.get(data_output_url)

      # Wait for page to load
      sleep 3

      # Export customer codes (顧客コード)
      Rails.logger.info "Exporting customer codes..."
      export_data_by_category(
        category: "【賃貸住宅管理】顧客登録",
        definition_name: "顧客基本情報出力定義"
      )

      # Navigate back to data output page
      Rails.logger.info "Navigating back to data output page..."
      @driver.get(data_output_url)
      sleep 3

      # Export property codes (物件コード)
      Rails.logger.info "Exporting property codes..."
      export_data_by_category(
        category: "【賃貸住宅管理】物件登録",
        definition_name: "物件基本情報出力定義"
      )

      Rails.logger.info "Master data export completed successfully"

      # Keep browser open for inspection
      sleep 5

    rescue => e
      Rails.logger.error "Error during master data export: #{e.message}"
      Rails.logger.error "Current URL: #{@driver.current_url}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end
  end

  def export_data_by_category(category:, definition_name:)
    Rails.logger.info "Exporting data for category: #{category}, definition: #{definition_name}"

    begin
      # Check for iframes and switch if necessary
      iframes = @driver.find_elements(tag_name: "iframe")
      Rails.logger.info "Found #{iframes.length} iframe(s)"

      if iframes.any?
        Rails.logger.info "Switching to iframe..."
        @driver.switch_to.frame(iframes.first)
      end

      sleep 2

      # Find the radio button for the specified category and definition
      Rails.logger.info "Looking for radio button with category: #{category} and definition: #{definition_name}"

      # Try multiple strategies to find the radio button
      radio_button = nil

      # Strategy 1: Find by text content nearby
      begin
        # Find text element containing the definition name
        text_element = @wait.until do
          @driver.find_element(xpath: "//*[contains(text(), '#{definition_name}')]")
        end
        Rails.logger.info "Found text element with definition name"

        # Find the closest radio button (input[type='radio'])
        radio_button = text_element.find_element(xpath: ".//preceding::input[@type='radio'][1] | .//following::input[@type='radio'][1] | .//ancestor::tr//input[@type='radio']")
        Rails.logger.info "Found radio button near definition name"
      rescue => e
        Rails.logger.warn "Strategy 1 failed: #{e.message}"
      end

      # Strategy 2: Find all radio buttons and match by nearby text
      unless radio_button
        Rails.logger.info "Trying strategy 2: checking all radio buttons"
        radio_buttons = @driver.find_elements(css: "input[type='radio']")
        Rails.logger.info "Found #{radio_buttons.length} radio buttons"

        radio_buttons.each_with_index do |rb, i|
          # Get the parent row or container
          parent = rb.find_element(xpath: "./ancestor::tr | ./ancestor::div[@class='row'] | ./ancestor::div[contains(@class, 'form-group')]")
          parent_text = parent.text

          Rails.logger.debug "Radio #{i}: Parent text: #{parent_text[0..100]}"

          if parent_text.include?(category) && parent_text.include?(definition_name)
            radio_button = rb
            Rails.logger.info "Found matching radio button at index #{i}"
            break
          end
        end
      end

      unless radio_button
        Rails.logger.error "Could not find radio button for #{category} - #{definition_name}"
        raise "Radio button not found"
      end

      # Click the radio button
      Rails.logger.info "Clicking radio button..."
      safe_click(radio_button)
      sleep 1

      # Find and click the output button (出力ボタン)
      Rails.logger.info "Looking for output button..."
      output_button = nil

      output_button_selectors = [
        { type: :xpath, value: "//input[@type='submit' and contains(@value, '出力')]" },
        { type: :xpath, value: "//button[contains(text(), '出力')]" },
        { type: :xpath, value: "//input[@type='button' and contains(@value, '出力')]" },
        { type: :css, value: "input[type='submit']" },
        { type: :css, value: "button[type='submit']" }
      ]

      output_button_selectors.each do |selector|
        begin
          Rails.logger.info "Trying selector: #{selector[:type]} = #{selector[:value]}"
          output_button = @driver.find_element(selector[:type], selector[:value])
          if output_button
            Rails.logger.info "Output button found with #{selector[:type]}: #{selector[:value]}"
            break
          end
        rescue Selenium::WebDriver::Error::NoSuchElementError
          next
        end
      end

      unless output_button
        Rails.logger.error "Could not find output button"
        raise "Output button not found"
      end

      # Click the output button
      Rails.logger.info "Clicking output button..."
      safe_click(output_button)

      # Wait for download/export to complete
      sleep 3

      # Switch back to default content if we were in an iframe
      @driver.switch_to.default_content if iframes.any?

      Rails.logger.info "Export completed for #{definition_name}"

    rescue => e
      Rails.logger.error "Error exporting data for #{category} - #{definition_name}: #{e.message}"
      Rails.logger.error "Current URL: #{@driver.current_url}"
      Rails.logger.error "Page source: #{@driver.page_source[0..2000]}"

      # Switch back to default content on error
      begin
        @driver.switch_to.default_content
      rescue
        # Ignore errors when switching back
      end

      raise
    end
  end

  # Headless mode helper: scroll element into view and wait
  def scroll_to_element(element)
    @driver.execute_script("arguments[0].scrollIntoView({behavior: 'smooth', block: 'center'});", element)
    sleep 0.5 # Small wait for scroll to complete
  end

  # Headless mode helper: click using JavaScript
  def js_click(element)
    @driver.execute_script("arguments[0].click();", element)
  end

  # Safe click that works in headless mode
  def safe_click(element)
    begin
      # First try: scroll into view
      scroll_to_element(element)

      # Second try: wait for element to be clickable
      @wait.until { element.displayed? && element.enabled? }

      # Try normal click first
      element.click
    rescue Selenium::WebDriver::Error::ElementClickInterceptedError,
           Selenium::WebDriver::Error::ElementNotInteractableError
      # Fallback: use JavaScript click
      Rails.logger.warn "Normal click failed, using JavaScript click"
      js_click(element)
    end
  end
end
