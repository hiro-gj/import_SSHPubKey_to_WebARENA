# `WebARENA Indigo API`でSSH公開鍵をインポートするWindowsスクリプト
## 参考資料
- （公式URL）[WebARENA Indigo APIのリファレンス](https://indigo.arena.ne.jp/userapi)
- （Zenn：mnodさん）[WebARENA Indigo の API を試す](https://zenn.dev/mnod/articles/ab039cccf3c975)

## 使い方
1. 全てのファイルを同じフォルダにダウンロードする。
2. 同じフォルダに`.env`ファイルを作成する。
   ```
   # WebARENA Indigo API Key
   # WebARENAにアクセスして、ダッシュボード - API鍵の管理 - API鍵の作成から取得する
   # clientId: <API鍵>
   # clientSecret: <API秘密鍵>
   clientId=xxxxxx
   clientSecret=xxxxxx
   ```
3. `import_SSHPubKey_to_WebARENA.cmd`を実行する

4. 既知の課題（2025.11.8現在）
[RSAは成功するが、ED25519は失敗する。。（2025.11.8現在）](https://github.com/hiro-gj/import_SSHPubKey_to_WebARENA/issues/1)

