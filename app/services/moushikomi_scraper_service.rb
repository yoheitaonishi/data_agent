require "cgi"
require "json"

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

    # スクレイピング完了後、CSV生成
    if @agentic_job_id
      job = AgenticJob.find(@agentic_job_id)
      Rails.logger.info "CSV生成開始..."
      job.generate_customers_csv
      Rails.logger.info "CSV生成完了"
    end
  ensure
    cleanup_driver
  end

  private

  def setup_driver
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-blink-features=AutomationControlled")

    @driver = Selenium::WebDriver.for :chrome, options: options
    @wait = Selenium::WebDriver::Wait.new(timeout: 15)
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
        safe_click(submit_button)
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
      staff_name = ENV.fetch("MOUSHIKOMI_STAFF_NAME")
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
      safe_click(submit_button)

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

    # 申込者情報（上部の表示用）
    data[:applicant_name] = extract_labeled_value("申込者名")
    data[:application_date] = extract_datetime_value(extract_labeled_value("申込日時"))
    data[:priority] = extract_labeled_value("番手").to_i rescue nil
    data[:applicant_email] = extract_labeled_value("申込者メールアドレス")
    data[:entry_status] = extract_labeled_value("申込ステータス")

    # 申込者タイプ（法人/個人）
    data[:applicant_type] = extract_applicant_type
    # 法人区分を保存
    data[:applicant_is_corporate] = (data[:applicant_type] == "法人")

    # 申込者詳細フォームから抽出
    # 氏名（フォームから）
    form_name = extract_name_from_form("氏名")
    data[:applicant_name] = form_name if form_name && !form_name.empty?

    # 氏名（カナ）
    data[:applicant_name_kana] = extract_name_from_form("氏名（カナ）")

    # 生年月日
    data[:applicant_birth_date] = extract_birth_date

    # 性別
    data[:applicant_gender] = extract_gender

    # 連絡先情報1（物件住所 = contact1）
    postal_code = extract_labeled_value("郵便番号")
    if postal_code
      parts = postal_code.split("-")
      data[:contact1_postal_code] = postal_code
    end
    data[:contact1_address1] = extract_labeled_value("住所")

    # 入居者1の携帯電話とメール
    data[:contact1_phone1] = extract_phone_number("携帯電話番号（※無い場合は自宅電話番号）")
    data[:contact1_email] = extract_email("メールアドレス")

    # 連絡先情報2（入居者2）
    data[:contact2_name] = extract_labeled_value("入居者2氏名")
    data[:contact2_postal_code] = postal_code  # 物件の郵便番号と同じ
    data[:contact2_address1] = data[:address]  # 物件住所と同じ
    data[:contact2_phone1] = extract_labeled_value("入居者2携帯電話番号")
    data[:contact2_email] = extract_labeled_value("入居者2メールアドレス")

    # 勤務先情報
    data[:workplace_name] = extract_workplace_name("勤務先/通学先名")
    data[:workplace_department] = extract_labeled_value("所属部署")
    data[:workplace_position] = extract_labeled_value("役職")

    # 勤務先所在地を取得
    workplace_location_data = extract_address_from_form("勤務先/通学先所在地")
    if workplace_location_data
      data[:workplace_postal_code] = workplace_location_data[:postal_code]
      data[:workplace_address] = workplace_location_data[:full_address]
    end

    # 勤務先電話番号を取得
    data[:workplace_phone] = extract_phone_number("勤務先/通学先電話番号")

    # 緊急連絡先情報
    data[:emergency_contact_name] = extract_labeled_value("緊急連絡先氏名")
    emergency_postal = extract_labeled_value("緊急連絡先郵便番号")
    data[:emergency_contact_postal_code] = emergency_postal if emergency_postal

    # 緊急連絡先住所を結合
    ec_pref = extract_labeled_value("緊急連絡先都道府県")
    ec_city = extract_labeled_value("緊急連絡先市区町村")
    ec_address = extract_labeled_value("緊急連絡先丁目・番地")
    ec_building = extract_labeled_value("緊急連絡先建物名・部屋番号")
    data[:emergency_contact_address] = [ec_pref, ec_city, ec_address, ec_building].compact.join("")

    data[:emergency_contact_phone] = extract_labeled_value("緊急連絡先携帯電話番号")
    data[:emergency_contact_relationship] = extract_labeled_value("続柄")

    # 契約日時情報
    contract_start_str = extract_labeled_value("契約開始日")
    data[:contract_start_date] = parse_japanese_date(contract_start_str)

    # 入居希望日を物件情報から取得
    move_in_str = extract_date_input_value("入居希望日")
    data[:move_in_date] = parse_japanese_date(move_in_str) || data[:contract_start_date]

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

  def extract_date_input_value(label_text)
    # Extract date value from input field with name="date"
    begin
      label_xpath = "//label[contains(., '#{label_text}')]"
      label_element = @driver.find_element(xpath: label_xpath)
      parent = label_element.find_element(xpath: "./ancestor::div[contains(@class, 'entry-format__item') or contains(@class, 'form-group')]")

      # Find input with name="date"
      date_input = parent.find_elements(xpath: ".//input[@name='date']").first
      if date_input
        value = date_input.attribute("value").to_s.strip
        return value unless value.empty?
      end

      Rails.logger.warn "Date input not found for '#{label_text}'"
      nil
    rescue => e
      Rails.logger.error "Error extracting date input for '#{label_text}': #{e.message}"
      nil
    end
  end

  def parse_japanese_date(date_str)
    return nil if date_str.nil? || date_str.empty?
    # Parse Japanese date format "2000/1/1" or "2000年1月1日"
    date_str = date_str.gsub(/[年月]/, "/").gsub(/日/, "")
    Date.parse(date_str) rescue nil
  end

  def parse_gender(gender_str)
    return nil if gender_str.nil? || gender_str.empty?
    case gender_str
    when /男/
      0
    when /女/
      1
    else
      2
    end
  end

  def extract_workplace_name(label_text)
    # Extract workplace name (only the first input, not the kana one)
    begin
      # Find label containing the text
      label_xpath = "//label[contains(., '#{label_text}')]"
      label_element = @driver.find_element(xpath: label_xpath)

      # Get parent container
      parent = label_element.find_element(xpath: "./ancestor::div[contains(@class, 'entry-format__item')]")

      # Find the first text input (which is the name, not kana)
      # Exclude inputs with name="text_kana"
      inputs = parent.find_elements(xpath: ".//input[@type='text' and @name='text']")
      if inputs.any?
        value = inputs[0].attribute("value").to_s.strip
        return value unless value.empty?
      end

      Rails.logger.warn "Workplace name input not found for '#{label_text}'"
      nil
    rescue => e
      Rails.logger.error "Error extracting workplace name for '#{label_text}': #{e.message}"
      nil
    end
  end

  def extract_name_from_form(label_text)
    # Extract name from form inputs (姓 and 名 fields)
    begin
      # Try to find label containing the text (may have nested spans)
      label_xpath = "//label[contains(., '#{label_text}')]"
      label_element = @driver.find_element(xpath: label_xpath)

      # Get parent container - look for entry-format__item
      parent = label_element.find_element(xpath: "./ancestor::div[contains(@class, 'entry-format__item')]")

      # Find last_name and first_name inputs
      inputs = parent.find_elements(xpath: ".//input[@type='text' and @class='form-control']")
      if inputs.length >= 2
        last_name = inputs[0].attribute("value").to_s.strip
        first_name = inputs[1].attribute("value").to_s.strip
        full_name = "#{last_name} #{first_name}".strip
        return full_name unless full_name.empty?
      end

      Rails.logger.warn "Name inputs not found for '#{label_text}', found #{inputs.length} inputs"
    rescue => e
      Rails.logger.warn "Could not extract name from form for '#{label_text}': #{e.message}"
      Rails.logger.warn e.backtrace.first(3).join("\n")
    end
    nil
  end

  def extract_birth_date
    # Extract birth date from select dropdowns (yyyy, mm, dd)
    begin
      label_xpath = "//label[contains(., '生年月日')]"
      label_element = @driver.find_element(xpath: label_xpath)

      # Get parent container
      parent = label_element.find_element(xpath: "./ancestor::div[contains(@class, 'entry-format__item')]")

      # Find year, month, day selects
      year_select = parent.find_element(xpath: ".//select[@name='yyyy']")
      month_select = parent.find_element(xpath: ".//select[@name='mm']")
      day_select = parent.find_element(xpath: ".//select[@name='dd']")

      # Get selected values using Selenium Select class
      require 'selenium-webdriver'
      year_value = Selenium::WebDriver::Support::Select.new(year_select).selected_options.first&.attribute("value")
      month_value = Selenium::WebDriver::Support::Select.new(month_select).selected_options.first&.attribute("value")
      day_value = Selenium::WebDriver::Support::Select.new(day_select).selected_options.first&.attribute("value")

      if year_value && month_value && day_value && year_value != "" && month_value != "" && day_value != ""
        return Date.parse("#{year_value}-#{month_value}-#{day_value}")
      else
        Rails.logger.warn "Birth date not fully selected: year=#{year_value}, month=#{month_value}, day=#{day_value}"
      end
    rescue => e
      Rails.logger.warn "Could not extract birth date: #{e.message}"
      Rails.logger.warn e.backtrace.first(3).join("\n")
    end
    nil
  end

  def extract_gender
    # Extract gender from radio buttons
    begin
      label_xpath = "//label[contains(text(), '性別')]"
      label_element = @driver.find_element(xpath: label_xpath)

      # Get parent container
      parent = label_element.find_element(xpath: "./ancestor::div[contains(@class, 'entry-format__item')]")

      # Find checked radio button - try multiple approaches
      # Approach 1: Look for checked attribute
      checked_radio = parent.find_elements(xpath: ".//input[@type='radio' and @checked]")
      if checked_radio.any?
        gender_value = checked_radio.first.attribute("value")
        return parse_gender(gender_value)
      end

      # Approach 2: Use Selenium's selected? method
      all_radios = parent.find_elements(xpath: ".//input[@type='radio']")
      all_radios.each do |radio|
        if radio.selected?
          gender_value = radio.attribute("value")
          return parse_gender(gender_value)
        end
      end

      Rails.logger.warn "No gender selected"
    rescue => e
      Rails.logger.warn "Could not extract gender: #{e.message}"
    end
    nil
  end

  def extract_address_from_form(label_text)
    # Extract address components from address form
    begin
      label_xpath = "//label[contains(., '#{label_text}')]"
      label_element = @driver.find_element(xpath: label_xpath)

      # Get parent container for the whole address section
      parent = label_element.find_element(xpath: "./ancestor::div[contains(@class, 'entry-format__address') or contains(@class, 'entry-format__item')]")

      # Extract postal code (2 parts)
      postal_inputs = parent.find_elements(xpath: ".//input[@name='zip_code_1' or @name='zip_code_2']")
      postal_code = nil
      if postal_inputs.length >= 2
        zip1 = postal_inputs[0].attribute("value").to_s.strip
        zip2 = postal_inputs[1].attribute("value").to_s.strip
        postal_code = "#{zip1} #{zip2}" if zip1 && zip2 && !zip1.empty?
      end

      # Extract address components
      state_input = parent.find_elements(xpath: ".//input[@name='state']").first
      city_input = parent.find_elements(xpath: ".//input[@name='city']").first
      street_input = parent.find_elements(xpath: ".//input[@name='street']").first
      other_input = parent.find_elements(xpath: ".//input[@name='other']").first

      state = state_input&.attribute("value").to_s.strip
      city = city_input&.attribute("value").to_s.strip
      street = street_input&.attribute("value").to_s.strip
      other = other_input&.attribute("value").to_s.strip

      # Combine address parts
      full_address = [state, city, street, other].reject(&:empty?).join("")

      return {
        postal_code: postal_code,
        full_address: full_address.empty? ? nil : full_address
      }
    rescue => e
      Rails.logger.warn "Could not extract address for '#{label_text}': #{e.message}"
      return { postal_code: nil, full_address: nil }
    end
  end

  def extract_phone_number(label_text)
    # Extract phone number from 3-part input fields
    begin
      label_xpath = "//label[contains(., '#{label_text}')]"
      label_element = @driver.find_element(xpath: label_xpath)

      # Get parent container
      parent = label_element.find_element(xpath: "./ancestor::div[contains(@class, 'entry-format__item')]")

      # Find phone number inputs
      phone_inputs = parent.find_elements(xpath: ".//input[@type='tel']")
      if phone_inputs.length >= 3
        part1 = phone_inputs[0].attribute("value").to_s.strip
        part2 = phone_inputs[1].attribute("value").to_s.strip
        part3 = phone_inputs[2].attribute("value").to_s.strip

        return "#{part1}-#{part2}-#{part3}" if part1 && part2 && part3 && !part1.empty?
      end
    rescue => e
      Rails.logger.warn "Could not extract phone number for '#{label_text}': #{e.message}"
    end
    nil
  end

  def extract_email(label_text)
    # Extract email from input field
    begin
      label_xpath = "//label[contains(., '#{label_text}')]"
      label_element = @driver.find_element(xpath: label_xpath)

      # Get parent container
      parent = label_element.find_element(xpath: "./ancestor::div[contains(@class, 'entry-format__item')]")

      # Find email input
      email_input = parent.find_element(xpath: ".//input[@type='email' or @type='text']")
      return email_input.attribute("value").to_s.strip if email_input
    rescue => e
      Rails.logger.warn "Could not extract email for '#{label_text}': #{e.message}"
    end
    nil
  end

  def extract_labeled_value(label_text)
    # Try multiple patterns to find label and its value
    # Pattern 1: Try to find input value after label (form inputs)
    begin
      # Find label containing the text
      label_xpath = "//label[contains(., '#{label_text}')]"
      label_element = @driver.find_element(xpath: label_xpath)

      # Get parent container
      parent = label_element.find_element(xpath: "./ancestor::div[contains(@class, 'entry-format__item')]")

      # Try to find input with value attribute
      inputs = parent.find_elements(xpath: ".//input[@value and @value!='']")
      if inputs.any?
        # If multiple inputs (like name fields), join them
        values = inputs.map { |input| input.attribute("value").to_s.strip }.reject(&:empty?)
        return values.join(" ") if values.any?
      end

      # Try to find selected option in select
      selects = parent.find_elements(xpath: ".//select")
      if selects.any?
        selected_values = selects.map do |select|
          selected = select.find_elements(xpath: ".//option[@selected]")
          selected.any? ? selected.first.attribute("value") : nil
        end.compact
        return selected_values.join("/") if selected_values.any?
      end

      # Try to find checked radio button
      radios = parent.find_elements(xpath: ".//input[@type='radio' and @checked]")
      if radios.any?
        return radios.first.attribute("value")
      end
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # Continue to fallback patterns
    end

    # Pattern 2: Try span with class='block' (for display-only fields)
    patterns = [
      { xpath: "//label[contains(text(), '#{label_text}')]/following-sibling::span[@class='block']" },
      { xpath: "//div[contains(@class, 'label') and contains(text(), '#{label_text}')]/following-sibling::span" },
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
    # Parse Japanese datetime format "2025/10/21 13:44" as JST (Japan Standard Time)
    # HTMLの日時は日本時間なので、明示的にJSTとしてパース
    Time.zone = 'Tokyo'
    Time.zone.parse(text) rescue nil
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
      safe_click(next_button)
    rescue Selenium::WebDriver::Error::NoSuchElementError
      next_link = @driver.find_element(xpath: "//a[contains(text(), '次へ') or contains(text(), '>')]")
      safe_click(next_link)
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
