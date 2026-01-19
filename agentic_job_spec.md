# モデル定義

## AgenticJob (取込履歴)

システム間連携におけるデータ取込ジョブの実行履歴を管理するモデル。

| カラム名 | データ型 | 論理名 | 説明 | 必須 | 備考 |
| --- | --- | --- | --- | --- | --- |
| id | integer | ID | プライマリキー | - | |
| executed_at | datetime | 実行日時 | ジョブが開始された日時 | ◯ | |
| source_system | string |取込元 | データの取得元システム名（例: イタンジ） | ◯ | |
| destination_system | string | 取込先 | データの連携先システム名（例: OBIC7） | ◯ | |
| status | string | ステータス | 実行結果の状態 | ◯ | processing, success, warning, error のいずれか |
| record_count | integer | 取込件数 | 処理されたレコード数 | ◯ | デフォルト: 0 |
| action_required | boolean | 要対応 | ユーザーの対処が必要かどうか | ◯ | デフォルト: false |
| error_message | text | エラー詳細 | エラーや警告の詳細メッセージ | - | |
| created_at | datetime | 作成日時 | レコード作成日時 | - | |
| updated_at | datetime | 更新日時 | レコード更新日時 | - | |
