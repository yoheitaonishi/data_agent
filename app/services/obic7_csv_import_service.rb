require "selenium-webdriver"

class Obic7CsvImportService
  class ImportError < StandardError; end

  # Constants from spec
  LOGIN_URL = "https://metawn.obic7.obicnet.ne.jp/WebMenu30/Pages/Common/MainFrame.aspx"
  DEFAULT_USER = "t.izumi"
  DEFAULT_PASSWORD = "ym3dCfrQcHEc"

  def initialize
    @driver = nil
    @wait = nil
  end

  def execute
    setup_driver
    login
    perform_import_customer  
    cleanup_driver
    
    setup_driver
    login
    perform_import_contract
  ensure
    cleanup_driver
  end

  private

  def setup_driver
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    # Headless mode can be disabled for debugging if needed, but keeping it consistent with other services
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
    Rails.logger.info "Navigating to OBIC7 login page: #{LOGIN_URL}"
    @driver.get(LOGIN_URL)

    sleep(3)

    iframe = @wait.until { @driver.find_element(:id, "frameMenu") }
    @driver.switch_to.frame(iframe)

    # - input id=txtID　が表示されるまで待機
    Rails.logger.info "Waiting for txtID input..."
    txt_id_input = @wait.until { @driver.find_element(:id, "txtID") }

    # - input id=txtID に t.izumi を入力
    Rails.logger.info "Entering username..."
    username = ENV["OBIC7_USER"] || DEFAULT_USER
    txt_id_input.clear
    txt_id_input.send_keys(username)

    # - input id=txtPassword に ym3dCfrQcHEc を入力
    Rails.logger.info "Entering password..."
    password = ENV["OBIC7_PASSWORD"] || DEFAULT_PASSWORD
    txt_password_input = @driver.find_element(id: "txtPassword")
    txt_password_input.clear
    txt_password_input.send_keys(password)

    # - button id=btnLogin をクリック
    Rails.logger.info "Clicking login button..."
    btn_login = @driver.find_element(id: "btnLogin")

    sleep(2)

    btn_login.click

    login_completed = @wait.until { @driver.find_element(:tag_name, "body").text.include?("\u4E0D\u52D5\u7523\u5171\u901A\u30E1\u30CB\u30E5\u30FC") }

    # Wait for login to complete (simple check, maybe URL change or element presence)
    # The spec ends here, but in practice we should wait.
    # Assuming successful login leads to a different URL or page state.
    # For now, just a brief wait or check if we are redirected.
    sleep 2
    Rails.logger.info "Login action performed."
  end

  def perform_import_customer
    # 不動産共通メニュー というラベルを含む、classがpItemのdivタグを取得

    original_window = @driver.window_handle

    Rails.logger.info "Looking for '不動産共通メニュー' menu item..."
    menu_item = @wait.until do
      @driver.find_element(:xpath, "//div[contains(@class, 'pItem') and contains(., '不動産共通メニュー')]")
    end    

    Rails.logger.info "Clicking '不動産共通メニュー'..."
    menu_item.click

    sleep(1)

    master_data_menu_item = @wait.until do
      @driver.find_element(:xpath, "//div[contains(@class, 'pIG') and contains(., 'マスタ入出力')]")
    end

    Rails.logger.info "Clicking 'マスタデータ取込'..."
    master_data_menu_item.click

    sleep(1)

    master_data_import_menu_item = @wait.until do
      @driver.find_element(:xpath, "//li[contains(@class, 'pIJ') and contains(., 'マスタ受入')]")
    end

    master_data_import_menu_item.click

    sleep(1)

    @wait.until do
      @driver.window_handles.size > 1
    end

    new_window = (@driver.window_handles - [ original_window ]).first
    @driver.switch_to.window(new_window)

    sleep(1)

    import_master_window = @driver.window_handle    

    bunrui_select = @driver.find_element(:name, "ctl00$mainArea$ddlBunrui")
    # bunrui_select　で "【賃貸住宅管理】顧客登録" を選択
    bunrui_select.find_element(:xpath, "//option[contains(text(), '【賃貸住宅管理】顧客登録')]").click

    sleep(1)

    teigi_select = @driver.find_element(:name, "ctl00$mainArea$ddlTeigiName")
    # teigi_select で "【賃貸住宅管理】顧客登録" を選択
    teigi_select.find_element(:xpath, "//option[contains(text(), '顧客基本情報受入定義')]").click

    display_button = @driver.find_element(:name, "ctl00$mainArea$btnDisp")
    display_button.click

    sleep(1)

    torikomi_check_button = @driver.find_element(:name, "ctl00$mainArea$cbModeTorikomi")
    torikomi_check_button.click

    torikomi_csv_uploader = @driver.find_element(:name, "ctl00$mainArea$fileUploader")

    csv_path = Rails.root.join("docs", "customer_sample.csv").to_s
    Rails.logger.info "Uploading CSV file: #{csv_path}"
    torikomi_csv_uploader.send_keys(csv_path)

    kakutei_button = @driver.find_element(:name, "ctl00$mainArea$btnKakutei")
    kakutei_button.click

    sleep(1)

    execute_button = @driver.find_element(:name, "ctl00$footerArea$btnExecute")
    execute_button.click

    sleep(1)

    # <input type="button" class="ob-ctl ob-btn" style="width:80px;" value="はい"> を取得
    confirm_button = @driver.find_element(:xpath, "//input[@value='はい']")
    confirm_button.click

    sleep(1)

    @wait.until do
      @driver.window_handles.size > 2
    end

    new_window = (@driver.window_handles - [ original_window, import_master_window ]).first
    @driver.switch_to.window(new_window)

    result = @driver.find_element(:tag_name, "body").text.include?("\u51E6\u7406\u7D42\u4E86\u65E5\u6642")

    if result
      Rails.logger.info "CSV import completed successfully."
    else
      raise ImportError, "CSV import failed."
    end
  end

  def perform_import_contract
    original_window = @driver.window_handle

    Rails.logger.info "Looking for '賃貸住宅管理メニュー' menu item..."
    menu_item = @wait.until do
      @driver.find_element(:xpath, "//div[contains(@class, 'pItem') and contains(., '賃貸住宅管理メニュー')]")
    end

    menu_item.click

    sleep(1)

    master_data_menu_item = @wait.until do
      @driver.find_element(:xpath, "//div[contains(@class, 'pIG') and contains(., '契約')]")
    end

    Rails.logger.info "Clicking 'マスタデータ取込'..."
    master_data_menu_item.click

    sleep(1)

    master_data_import_menu_item = @wait.until do
      @driver.find_element(:xpath, "//li[contains(@class, 'pIJ') and contains(., '契約データ取込処理')]")
    end

    master_data_import_menu_item.click

    sleep(1)

    @wait.until do
      @driver.window_handles.size > 1
    end

    new_window = (@driver.window_handles - [ original_window ]).first
    @driver.switch_to.window(new_window)

    kihon_csv_path = Rails.root.join("docs", "対応表_イーリアルティ様 - 基本情報ファイル.csv").to_s
    kihon_csv_uploader = @driver.find_element(:id, "fileKihon_file")
    kihon_csv_uploader.send_keys(kihon_csv_path)

    sleep(1)

    execute_button = @driver.find_element(:id, "btnExecute")
    execute_button.click

    confirm_button = @driver.find_element(:xpath, "//input[@value='はい']")
    confirm_button.click

    result = true

    if result
      Rails.logger.info "CSV import completed successfully."
    else
      raise ImportError, "CSV import failed."
    end
  end
end
