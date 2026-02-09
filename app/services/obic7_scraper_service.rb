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
      # Navigate through menu: 不動産共通メニュー -> マスタ入出力 -> マスタ出力
      navigate_to_master_io_menu

      # Export customer codes (顧客コード)
      Rails.logger.info "Exporting customer codes..."
      export_data_by_category(
        category: "【賃貸住宅管理】顧客登録",
        definition_name: "顧客基本情報出力定義"
      )

      # Navigate back to master output page
      Rails.logger.info "Navigating back to master output page..."
      navigate_to_master_io_menu
      sleep 3

      # Export property codes (物件コード)
      Rails.logger.info "Exporting property codes..."
      export_data_by_category(
        category: "【賃貸住宅管理】物件登録",
        definition_name: "物件基本情報出力定義"
      )

      Rails.logger.info "Master data export completed successfully"

      # Keep browser open for inspection
      sleep 10

    rescue => e
      Rails.logger.error "Error during master data export: #{e.message}"
      Rails.logger.error "Current URL: #{@driver.current_url}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end
  end

  def navigate_to_master_io_menu
    Rails.logger.info "Navigating to Master I/O menu via menu selection..."

    begin
      # Step 1: Click "不動産共通メニュー"
      click_menu_item("不動産共通メニュー")
      sleep 3

      # Step 2: Click "マスタ入出力"
      click_menu_item("マスタ入出力")
      sleep 3

      # Step 3: Click "マスタ出力"
      click_menu_item("マスタ出力")
      sleep 3

      Rails.logger.info "Successfully navigated to Master Output menu"

    rescue => e
      Rails.logger.error "Error navigating to Master I/O menu: #{e.message}"
      Rails.logger.error "Current URL: #{@driver.current_url}"
      Rails.logger.error e.backtrace.join("\n")

      # Try to switch back to default content
      begin
        @driver.switch_to.default_content
      rescue
        # Ignore errors when switching back
      end

      raise
    end
  end

  def click_menu_item(menu_text)
    Rails.logger.info "Looking for '#{menu_text}' menu item..."

    # Check for iframes
    iframes = @driver.find_elements(tag_name: "iframe")
    Rails.logger.info "Found #{iframes.length} iframe(s)"

    menu_item = nil
    menu_selectors = [
      { type: :xpath, value: "//a[contains(text(), '#{menu_text}')]" },
      { type: :xpath, value: "//*[contains(text(), '#{menu_text}')]" },
      { type: :link_text, value: menu_text }
    ]

    # Try in main content first
    menu_selectors.each do |selector|
      begin
        Rails.logger.info "Trying selector: #{selector[:type]} = #{selector[:value]}"
        menu_item = @driver.find_element(selector[:type], selector[:value])
        if menu_item
          Rails.logger.info "Found '#{menu_text}' with #{selector[:type]}"
          break
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        next
      end
    end

    # If not found, try switching to iframes
    if !menu_item && iframes.any?
      iframes.each_with_index do |iframe, i|
        begin
          Rails.logger.info "Switching to iframe #{i}..."
          @driver.switch_to.frame(iframe)

          menu_selectors.each do |selector|
            begin
              menu_item = @driver.find_element(selector[:type], selector[:value])
              if menu_item
                Rails.logger.info "Found '#{menu_text}' in iframe #{i}"
                break
              end
            rescue Selenium::WebDriver::Error::NoSuchElementError
              next
            end
          end

          break if menu_item
          @driver.switch_to.default_content
        rescue => e
          Rails.logger.warn "Error in iframe #{i}: #{e.message}"
          @driver.switch_to.default_content
        end
      end
    end

    unless menu_item
      Rails.logger.error "Could not find '#{menu_text}' menu item"
      Rails.logger.error "Available links:"
      links = @driver.find_elements(tag_name: "a")
      links.first(20).each_with_index do |link, i|
        Rails.logger.error "Link #{i}: #{link.text}"
      end
      raise "'#{menu_text}' menu item not found"
    end

    # Click the menu item
    Rails.logger.info "Clicking '#{menu_text}'..."
    safe_click(menu_item)

    # Switch back to default content
    @driver.switch_to.default_content
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

      # Find and select from category dropdown (分類)
      Rails.logger.info "Looking for category dropdown (分類)..."
      category_dropdown = nil

      category_selectors = [
        { type: :id, value: "ddlCategory" },
        { type: :name, value: "ddlCategory" },
        { type: :xpath, value: "//select[contains(@id, 'Category')]" },
        { type: :xpath, value: "//select[contains(@name, 'Category')]" },
        { type: :css, value: "select" }
      ]

      category_selectors.each do |selector|
        begin
          Rails.logger.info "Trying selector: #{selector[:type]} = #{selector[:value]}"
          category_dropdown = @driver.find_element(selector[:type], selector[:value])
          if category_dropdown
            Rails.logger.info "Category dropdown found with #{selector[:type]}: #{selector[:value]}"
            break
          end
        rescue Selenium::WebDriver::Error::NoSuchElementError
          next
        end
      end

      unless category_dropdown
        Rails.logger.error "Could not find category dropdown"
        # Log all select elements
        selects = @driver.find_elements(tag_name: "select")
        Rails.logger.error "Found #{selects.length} select elements:"
        selects.each_with_index do |select, i|
          Rails.logger.error "Select #{i}: id=#{select.attribute('id')}, name=#{select.attribute('name')}"
        end
        raise "Category dropdown not found"
      end

      # Select category from dropdown
      Rails.logger.info "Selecting category: #{category}"
      select_category = Selenium::WebDriver::Support::Select.new(category_dropdown)
      select_category.select_by(:text, category)
      sleep 2 # Wait for definition dropdown to update

      # Find and select from definition dropdown (定義名)
      Rails.logger.info "Looking for definition dropdown (定義名)..."
      definition_dropdown = nil

      definition_selectors = [
        { type: :id, value: "ddlDefinition" },
        { type: :name, value: "ddlDefinition" },
        { type: :xpath, value: "//select[contains(@id, 'Definition')]" },
        { type: :xpath, value: "//select[contains(@name, 'Definition')]" }
      ]

      definition_selectors.each do |selector|
        begin
          Rails.logger.info "Trying selector: #{selector[:type]} = #{selector[:value]}"
          definition_dropdown = @driver.find_element(selector[:type], selector[:value])
          if definition_dropdown
            Rails.logger.info "Definition dropdown found with #{selector[:type]}: #{selector[:value]}"
            break
          end
        rescue Selenium::WebDriver::Error::NoSuchElementError
          next
        end
      end

      # If still not found, try finding the second select element
      unless definition_dropdown
        Rails.logger.info "Trying to find second select element..."
        selects = @driver.find_elements(tag_name: "select")
        if selects.length >= 2
          definition_dropdown = selects[1]
          Rails.logger.info "Using second select element as definition dropdown"
        end
      end

      unless definition_dropdown
        Rails.logger.error "Could not find definition dropdown"
        raise "Definition dropdown not found"
      end

      # Select definition from dropdown
      Rails.logger.info "Selecting definition: #{definition_name}"
      select_definition = Selenium::WebDriver::Support::Select.new(definition_dropdown)
      select_definition.select_by(:text, definition_name)
      sleep 1

      # Find and click the output button (出力ボタン)
      Rails.logger.info "Looking for output button..."
      output_button = nil

      output_button_selectors = [
        { type: :xpath, value: "//input[@type='submit' and contains(@value, '出力')]" },
        { type: :xpath, value: "//button[contains(text(), '出力')]" },
        { type: :xpath, value: "//input[@type='button' and contains(@value, '出力')]" },
        { type: :id, value: "btnOutput" },
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
        # Log all buttons and inputs
        buttons = @driver.find_elements(css: "button, input[type='button'], input[type='submit']")
        Rails.logger.error "Found #{buttons.length} buttons/inputs:"
        buttons.each_with_index do |btn, i|
          Rails.logger.error "Button #{i}: type=#{btn.attribute('type')}, value=#{btn.attribute('value')}, text=#{btn.text}"
        end
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
