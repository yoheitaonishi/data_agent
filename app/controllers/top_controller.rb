class TopController < ApplicationController
  def index
    @initial_data = AgenticJob.order(id: :desc).map do |job|
      {
        id: job.id,
        date: job.executed_at.strftime('%Y/%m/%d %H:%M:%S'),
        source: job.source_system,
        destination: job.destination_system,
        status: job.status,
        count: job.record_count,
        requiredAction: job.action_required,
        errorDetail: job.error_message
      }
    end
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
end
