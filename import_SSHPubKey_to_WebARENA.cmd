@echo off
REM WebARENA Indigo API に対して SSH公開鍵を登録するための Windows バッチスクリプト
REM 要件:
REM  - .env から clientId, clientSecret を読み取る
REM  - アクセストークンを取得して accessToken に格納
REM  - ユーザーに ssh 名を入力させ、GUI で公開鍵ファイルを選択し内容を読み取る
REM  - SSH 鍵登録 API に対してリクエストを送る
cd /d %~dp0
setlocal enabledelayedexpansion
echo [DBG] START script path=%~dp0

echo === .env から設定を読み取ります ===

REM .env を PowerShell で安全に読み取り一時バッチに書き出して読み込む（UTF-8 / BOM 対応）
powershell -NoProfile -Command ^
"if (Test-Path '.env') { ^
  try { ^
    $lines = Get-Content -Encoding UTF8 '.env'; ^
  } catch { ^
    Write-Error 'Failed to read .env'; exit 2 ^
  } ^
  $out = ''; ^
  foreach($line in $lines){ ^
    $trim = $line.Trim(); ^
    if ([string]::IsNullOrWhiteSpace($trim) -or $trim.StartsWith('#')) { continue } ^
    $parts = $trim.Split('=', 2); ^
    if ($parts.Length -ne 2) { continue } ^
    $key = $parts[0].Trim(); ^
    if ([string]::IsNullOrEmpty($key)) { continue } ^
    $value = $parts[1].Trim(); ^
    $value = $value -replace '\"','\\\"'; ^
    $out += \"set $key=$value`r`n\" ^
  } ^
  if ([string]::IsNullOrEmpty($out)) { ^
    Write-Output 'NOVARS'; exit 3 ^
  } ^
  Set-Content -Encoding ASCII -Path env_vars.tmp.cmd -Value $out; ^
  Write-Output 'OK' ^
} else { Write-Output 'NOFILE'; exit 2 }"
echo ---- env_vars.tmp.cmd の内容 ----
if exist env_vars.tmp.cmd (
  type env_vars.tmp.cmd
) else (
  echo env_vars.tmp.cmd が作成されていません
)
call env_vars.tmp.cmd 2>nul
echo ---- 読み込んだ変数 ----
echo clientId=%clientId%
echo clientSecret=%clientSecret%
if exist env_vars.tmp.cmd del env_vars.tmp.cmd

if not defined clientId (
  echo clientId が .env に見つかりません。
  echo .env に以下のように記載してください:
  echo clientId={API鍵}
  echo clientSecret={API秘密鍵}
  pause
  exit /b 1
)
if not defined clientSecret (
  echo clientSecret が .env に見つかりません。
  pause
  exit /b 1
)

REM sshKeyEndpoint が未定義の場合、既定の Indigo エンドポイントを自動設定する
if not defined sshKeyEndpoint (
  set "sshKeyEndpoint=https://api.customer.jp/webarenaIndigo/v1/vm/sshkey"
  echo sshKeyEndpoint を自動設定しました: %sshKeyEndpoint%
)

echo.
echo === アクセストークンを取得します ===
powershell -ExecutionPolicy Bypass -File get_token.ps1 > accessToken.tmp.cmd
if errorlevel 1 (
  echo アクセストークン取得失敗
  del accessToken.tmp.cmd 2>nul
  pause
  exit /b 1
)
call accessToken.tmp.cmd
del accessToken.tmp.cmd
echo accessToken を設定しました。

echo.
echo.
echo === SSH鍵名入力と公開鍵ファイル選択 ===
set /p "sshName=SSH鍵名を入力してください: "
if "%sshName%"=="" (
  echo [ERR] SSH鍵名が空です。
  pause
  exit /b 1
)

echo 公開鍵ファイル選択ダイアログを表示します...
powershell -NoProfile -ExecutionPolicy Bypass -File select_pubkey.ps1 > ssh_pub.tmp
if errorlevel 1 (
  echo [ERR] 公開鍵ファイル選択がキャンセルまたは失敗/読取失敗しました。
  del ssh_pub.tmp 2>nul
  pause
  exit /b 1
)
set /p "sshKey=" < ssh_pub.tmp
del ssh_pub.tmp
if "%sshKey%"=="" (
  echo [ERR] 公開鍵内容が空です。
  pause
  exit /b 1
)

echo [DBG] 入力 sshName="%sshName%"
echo [DBG] 公開鍵先頭60=%sshKey:~0,60%

if "%sshName%"=="" (
  echo SSH鍵の名前が入力されていません。
  pause
  exit /b 1
)

echo SSH鍵を登録APIに送信します: %sshKeyEndpoint%
echo [DBG] 送信直前 sshName="%sshName%" / sshKeyEndpoint="%sshKeyEndpoint%"
for /f %%L in ('powershell -NoProfile -Command "[int](\"%sshKey%\".Length)"') do set "sshKeyLen=%%L"
echo [DBG] 公開鍵長=%sshKeyLen% 先頭60=%sshKey:~0,60%

echo [DBG] PowerShell API呼び出し開始
powershell -ExecutionPolicy Bypass -File register_key.ps1
if errorlevel 1 (
  echo [DBG][ERR] API 呼び出し失敗
) else (
  echo [DBG] API 呼び出し成功
)

echo.
echo 完了しました。
pause
