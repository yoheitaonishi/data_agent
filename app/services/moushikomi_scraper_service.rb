require 'cgi'
require 'json'

class MoushikomiScraperService
  class ScrapingError < StandardError; end

  def initialize
    @driver = nil
    @wait = nil
    @agentic_job_id = nil
  end

  def scrape_contract_data(agentic_job_id: nil)
    @agentic_job_id = agentic_job_id
    setup_driver
    login
    navigate_to_contract_page
    scrape_all_pages
  ensure
    cleanup_driver
  end

  private

  def setup_driver
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--headless") # デバッグ用に一時的に無効化

    @driver = Selenium::WebDriver.for :chrome, options: options
    @wait = Selenium::WebDriver::Wait.new(timeout: 10)
  end

  def cleanup_driver
    @driver&.quit
  end

  def login
    # Step 1: Main login
    Rails.logger.info "Navigating to login page: #{ENV.fetch('MOUSHIKOMI_LOGIN_URL')}"
    @driver.get(ENV.fetch("MOUSHIKOMI_LOGIN_URL"))

    begin
      Rails.logger.info "Looking for email field..."
      email_field = @wait.until { @driver.find_element(name: "email") }
      Rails.logger.info "Email field found, entering email..."
      email_field.send_keys(ENV.fetch("MOUSHIKOMI_EMAIL"))

      Rails.logger.info "Looking for password field..."
      password_field = @driver.find_element(name: "password")
      Rails.logger.info "Password field found, entering password..."
      password_field.send_keys(ENV.fetch("MOUSHIKOMI_PASSWORD"))

      Rails.logger.info "Submitting login form..."
      # Try to submit the form directly instead of clicking button
      begin
        form = @driver.find_element(css: "form")
        form.submit
        Rails.logger.info "Form submitted successfully"
      rescue => e
        Rails.logger.warn "Form submit failed, trying button click: #{e.message}"
        submit_button = find_submit_button
        submit_button.click
        Rails.logger.info "Submit button clicked successfully"
      end

      # Wait for login to complete
      Rails.logger.info "Waiting for login to complete..."
      @wait.until { @driver.current_url != ENV.fetch("MOUSHIKOMI_LOGIN_URL") }
      Rails.logger.info "Main login completed. Current URL: #{@driver.current_url}"

    rescue => e
      Rails.logger.error "Error during main login: #{e.message}"
      Rails.logger.error "Current URL: #{@driver.current_url}"
      Rails.logger.error "Page source: #{@driver.page_source[0..500]}" # First 500 chars
      raise
    end

    # Step 2: Staff login (from table)
    begin
      Rails.logger.info "Looking for staff in table: #{ENV.fetch('MOUSHIKOMI_STAFF_NAME')}"

      # Wait for table to load
      @wait.until { @driver.find_element(css: "table.jambo_table") }

      # Find the row containing the staff name
      staff_name = ENV.fetch('MOUSHIKOMI_STAFF_NAME')
      staff_row = @wait.until do
        @driver.find_element(xpath: "//td[contains(text(), '#{staff_name}')]/parent::tr")
      end
      Rails.logger.info "Staff row found for: #{staff_name}"

      # Check if this staff requires password (has password input field)
      password_fields = staff_row.find_elements(css: "input[type='password']")

      if password_fields.any?
        Rails.logger.info "Password field found, entering password..."
        password_field = password_fields.first
        password_field.send_keys(ENV.fetch("MOUSHIKOMI_STAFF_PASSWORD"))
      else
        Rails.logger.info "No password required for this staff"
      end

      # Find and click the submit button in the same row
      Rails.logger.info "Looking for submit button in staff row..."
      submit_button = staff_row.find_element(css: "button[type='submit']")
      Rails.logger.info "Submit button found, clicking..."
      submit_button.click

      # Wait for staff login to complete
      Rails.logger.info "Waiting for staff login to complete..."
      @wait.until { @driver.current_url != "https://moushikomi-uketsukekun.com/accounts" }
      Rails.logger.info "Staff login completed. Current URL: #{@driver.current_url}"

    rescue => e
      Rails.logger.error "Error during staff login: #{e.message}"
      Rails.logger.error "Current URL: #{@driver.current_url}"
      Rails.logger.error "Page source: #{@driver.page_source[0..1000]}" # First 1000 chars
      raise
    end
  end

  def navigate_to_contract_page
    Rails.logger.info "Navigating to contract page..."
    @driver.get(ENV.fetch("MOUSHIKOMI_CONTRACT_URL"))
    @wait.until { @driver.find_element(css: "table.itandi-bb-ui__Table") }
    Rails.logger.info "Contract page loaded"
  end

  def scrape_all_pages
    all_data = []
    page_number = 1

    loop do
      Rails.logger.info "Scraping page #{page_number}..."

      # Scrape current page
      page_data = scrape_current_page
      all_data.concat(page_data)

      # Check if there's a next page
      break unless has_next_page?

      # Click next page
      click_next_page
      page_number += 1

      # Wait for new page to load
      @wait.until { @driver.find_element(css: "table") }
    end

    {
      success: true,
      count: all_data.length,
      data: all_data,
      pages_scraped: page_number
    }
  rescue => e
    Rails.logger.error "Scraping error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    {
      success: false,
      error: e.message,
      data: all_data,
      count: all_data.length
    }
  end

  def scrape_current_page
    # Wait for table to fully load
    @wait.until { @driver.find_element(css: "tbody") }
    sleep 2 # Extra wait for dynamic content

    # Get tbody element and then its rows
    tbody = @driver.find_element(css: "tbody")
    rows = tbody.find_elements(css: "tr")

    page_data = []

    Rails.logger.info "Found #{rows.length} data rows in tbody"

    if rows.empty?
      Rails.logger.error "No rows found in tbody. Page source:"
      Rails.logger.error @driver.page_source[0..2000]
      return page_data
    end

    rows.each_with_index do |row, index|
      begin
        Rails.logger.info "Processing row #{index + 1}/#{rows.length}..."

        # Find the property link in the row - try multiple selectors
        link_element = nil
        link_selectors = [
          "a[href*='/entry_heads/']",  # Most reliable - matches href pattern
          "a.itandi-bb-ui__TextLink--Primary",
          "a.itandi-bb-ui__TextLink",
          "td:nth-child(3) a",  # Property column is 3rd
          "td a"
        ]

        link_selectors.each do |selector|
          begin
            Rails.logger.debug "Trying selector: #{selector}"
            link_element = row.find_element(css: selector)
            if link_element
              Rails.logger.info "Link found with selector: #{selector}"
              break
            end
          rescue Selenium::WebDriver::Error::NoSuchElementError
            Rails.logger.debug "Selector '#{selector}' not found"
            next
          end
        end

        unless link_element
          Rails.logger.error "Could not find link in row #{index + 1}"
          Rails.logger.error "Row HTML: #{row.attribute('innerHTML')[0..500]}"
          next
        end

        property_name = link_element.text
        detail_url = link_element.attribute("href")

        Rails.logger.info "Found property: #{property_name}, URL: #{detail_url}"

        # Navigate to detail page
        full_url = detail_url.start_with?("http") ? detail_url : "https://moushikomi-uketsukekun.com#{detail_url}"
        @driver.get(full_url)

        # Wait for detail page to load
        @wait.until { @driver.find_element(css: "body") }
        sleep 1 # Give time for content to load

        # Extract all detail data from detail page
        detail_data = extract_detail_data

        # Extract entry_head_id from URL
        entry_head_id = detail_url.match(/entry_heads\/(\d+)/)[1] rescue nil

        Rails.logger.info "Extracted detail data for: #{property_name}"

        # Save to database
        begin
          contract_entry = ContractEntry.find_or_initialize_by(entry_head_id: entry_head_id)
          contract_entry.assign_attributes(
            property_name: property_name,
            detail_url: full_url,
            agentic_job_id: @agentic_job_id,
            **detail_data
          )
          contract_entry.save!
          Rails.logger.info "Saved ContractEntry ID: #{contract_entry.id}"
        rescue => e
          Rails.logger.error "Error saving to database: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end

        # Go back to list page
        @driver.navigate.back
        @wait.until { @driver.find_element(css: "tbody") }
        sleep 1 # Wait for page to stabilize

        # Re-find rows after navigation
        tbody = @driver.find_element(css: "tbody")
        rows = tbody.find_elements(css: "tr")

        page_data << {
          property_name: property_name,
          applicant_name: detail_data[:applicant_name],
          detail_url: full_url,
          entry_head_id: entry_head_id,
          saved_to_db: true
        }

      rescue => e
        Rails.logger.error "Error processing row #{index + 1}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        # Try to go back to list page if we're on detail page
        begin
          @driver.navigate.back
          @wait.until { @driver.find_element(css: "table.itandi-bb-ui__Table") }
          rows = @driver.find_elements(css: "table.itandi-bb-ui__Table tbody tr")
        rescue
          # Continue with next row
        end
      end
    end

    page_data
  end

  def extract_applicant_name
    extract_labeled_value("申込者名")
  end

  def extract_detail_data
    # Extract all data from detail page
    data = {}

    # 物件情報
    data[:room_id] = extract_labeled_value("部屋ID")
    data[:address] = extract_labeled_value("住所")
    data[:area] = extract_numeric_value(extract_labeled_value("広さ"))
    data[:rent] = extract_money_value(extract_labeled_value("家賃"))
    data[:management_fee] = extract_money_value(extract_labeled_value("管理費"))

    # 敷金/礼金/保証金
    deposit_info = extract_labeled_value("敷金 / 礼金 / 保証金")
    if deposit_info
      parts = deposit_info.split("/").map(&:strip)
      data[:deposit] = extract_money_value(parts[0]) if parts[0]
      data[:key_money] = extract_money_value(parts[1]) if parts[1]
      data[:guarantee_deposit] = extract_money_value(parts[2]) if parts[2]
    end

    # 申込者情報
    data[:applicant_name] = extract_labeled_value("申込者名")
    data[:application_date] = extract_datetime_value(extract_labeled_value("申込日時"))
    data[:priority] = extract_labeled_value("番手").to_i rescue nil
    data[:applicant_email] = extract_labeled_value("申込者メールアドレス")
    data[:entry_status] = extract_labeled_value("申込ステータス")

    # 申込者タイプ（法人/個人）
    data[:applicant_type] = extract_applicant_type

    # 仲介会社情報
    data[:broker_company_name] = extract_labeled_value("仲介会社名")
    data[:broker_phone] = extract_labeled_value("仲介会社固定電話番号")

    staff_info = extract_labeled_value("担当者名 / 担当者Tel")
    if staff_info
      parts = staff_info.split("/").map(&:strip)
      data[:broker_staff_name] = parts[0] if parts[0]
      data[:broker_staff_phone] = parts[1] if parts[1]
    end

    data[:broker_staff_email] = extract_labeled_value("担当者Eメール")

    # 適格請求書 - 登録番号
    data[:registration_number] = extract_labeled_value("登録番号")

    # 保証会社関連
    data[:guarantee_company] = extract_labeled_value("利用保証会社")
    data[:guarantee_result] = extract_labeled_value("保証審査結果")

    # 連帯保証人
    data[:joint_guarantor_usage] = extract_labeled_value("利用有無")

    # 契約方法
    data[:contract_method] = extract_labeled_value("契約方法")

    # 申込者編集権限
    data[:applicant_edit_permission] = extract_labeled_value("申込者の編集権限")

    # 申込方法
    data[:application_method] = extract_labeled_value("申込方法")

    Rails.logger.info "Extracted data: #{data.inspect}"
    data
  end

  def extract_labeled_value(label_text)
    # Try multiple patterns to find label and its value
    patterns = [
      # Pattern 1: <label>Text</label><span class='block'>Value</span>
      { xpath: "//label[contains(text(), '#{label_text}')]/following-sibling::span" },
      # Pattern 2: <div class='label'>Text</div><span>Value</span>
      { xpath: "//div[contains(@class, 'label') and contains(text(), '#{label_text}')]/following-sibling::span" },
      # Pattern 3: <div class='label'>Text</div> followed by <span class='pa-x-12'>Value</span>
      { xpath: "//div[contains(text(), '#{label_text}')]/following-sibling::span[@class='pa-x-12']" }
    ]

    patterns.each do |pattern|
      begin
        element = @driver.find_element(xpath: pattern[:xpath])
        value = element.text.strip
        return value unless value.empty?
      rescue Selenium::WebDriver::Error::NoSuchElementError
        next
      end
    end

    Rails.logger.warn "Could not find value for label: #{label_text}"
    nil
  end

  def extract_money_value(text)
    return nil if text.nil? || text.empty?
    # Remove currency symbol and commas, extract number
    text.gsub(/[^\d.]/, "").to_f rescue nil
  end

  def extract_numeric_value(text)
    return nil if text.nil? || text.empty?
    # Extract first number from text
    text.scan(/[\d.]+/).first.to_f rescue nil
  end

  def extract_datetime_value(text)
    return nil if text.nil? || text.empty?
    # Parse Japanese datetime format "2025/10/21 13:44"
    DateTime.parse(text) rescue nil
  end

  def extract_applicant_type
    # Extract from React component props: EntryHeadCategoryLabel
    # Example: data-react-props="{...&quot;isCorp&quot;:true...}"
    begin
      # Find the EntryHeadCategoryLabel component
      element = @driver.find_element(xpath: "//div[@data-react-class='EntryHeadCategoryLabel']")
      props_json = element.attribute("data-react-props")

      if props_json
        # Decode HTML entities and parse JSON
        props_json = CGI.unescapeHTML(props_json)
        props = JSON.parse(props_json)

        # Check isCorp flag
        if props["isCorp"] == true
          return "法人"
        else
          return "個人"
        end
      end
    rescue => e
      Rails.logger.warn "Could not extract applicant type: #{e.message}"

      # Fallback: try to find label text "法人" or "個人"
      begin
        if @driver.find_elements(xpath: "//span[contains(text(), '法人')]").any?
          return "法人"
        elsif @driver.find_elements(xpath: "//span[contains(text(), '個人')]").any?
          return "個人"
        end
      rescue
        # Ignore fallback errors
      end
    end

    nil
  end

  def has_next_page?
    # Look for pagination elements - adjust selector based on actual HTML
    # Common patterns:
    # - Link with text "次へ" or ">"
    # - Button with class "next" or "pagination-next"
    # - Disabled state on "next" button when on last page

    begin
      next_button = @driver.find_element(css: "a.next:not(.disabled)")
      !next_button.nil?
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # Try alternative selectors
      begin
        next_link = @driver.find_element(xpath: "//a[contains(text(), '次へ') or contains(text(), '>')]")
        !next_link.nil?
      rescue Selenium::WebDriver::Error::NoSuchElementError
        false
      end
    end
  end

  def click_next_page
    begin
      next_button = @driver.find_element(css: "a.next:not(.disabled)")
      next_button.click
    rescue Selenium::WebDriver::Error::NoSuchElementError
      next_link = @driver.find_element(xpath: "//a[contains(text(), '次へ') or contains(text(), '>')]")
      next_link.click
    end
  end

  def find_submit_button
    # Try multiple selectors for submit button
    selectors = [
      { type: :css, value: "button[type='submit']" },
      { type: :css, value: "input[type='submit']" },
      { type: :css, value: "button.btn-primary" },
      { type: :css, value: "button.submit" },
      { type: :css, value: "input.btn-primary" },
      { type: :xpath, value: "//button[contains(text(), 'ログイン')]" },
      { type: :xpath, value: "//input[@value='ログイン']" },
      { type: :xpath, value: "//button[contains(@class, 'login')]" },
      { type: :css, value: "form button" },
      { type: :css, value: "form input[type='button']" }
    ]

    selectors.each do |selector|
      begin
        element = @driver.find_element(selector[:type], selector[:value])
        Rails.logger.info "Found submit button with #{selector[:type]}: #{selector[:value]}"
        return element if element.displayed? && element.enabled?
      rescue Selenium::WebDriver::Error::NoSuchElementError
        next
      end
    end

    raise Selenium::WebDriver::Error::NoSuchElementError, "Could not find submit button with any known selector"
  end
end
