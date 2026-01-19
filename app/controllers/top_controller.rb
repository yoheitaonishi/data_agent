class TopController < ApplicationController
  def index
  end

  def dev
    @title = "取得中..."

    # シンプルなコードとして、コントローラー内で直接実行します。
    # 実際の本番運用ではバックグラウンドジョブでの実行を推奨します。

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

    driver = Selenium::WebDriver.for :chrome, options: options

    begin
      driver.get("https://www.yahoo.co.jp/")
      @title = driver.title
    ensure
      driver.quit
    end
  rescue => e
    @title = "エラーが発生しました: #{e.message}"
  end

  def contract_data
    scraper = MoushikomiScraperService.new
    result = scraper.scrape_contract_data

    @contract_data = result[:data] || []
    @pages_scraped = result[:pages_scraped]

    if result[:success]
      @status = "契約準備中データを#{result[:count]}件取得しました（#{@pages_scraped}ページ）"
    else
      @status = "エラーが発生しました: #{result[:error]}"
    end
  rescue => e
    @status = "エラーが発生しました: #{e.message}"
    @contract_data = []
    @pages_scraped = 0
    logger.error "contract_data エラー: #{e.message}"
    logger.error e.backtrace.join("\n")
  end
end
