# 公開鍵ファイル選択用 PowerShell スクリプト
# 標準出力に 1 行化した公開鍵文字列を返す。キャンセル時は終了コード 9。

Add-Type -AssemblyName System.Windows.Forms

$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Filter = 'all files (*.*)|*.*'
$dlg.Title  = 'SSH公開鍵ファイルを選択してください'

if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Error 'User cancelled file selection.'
    exit 9
}

# ファイル内容取得
try {
    # UTF8(BOM/無BOM) を想定。失敗時は ASCII / Default も試行
    $raw = Get-Content -Encoding UTF8 -Raw -ErrorAction Stop $dlg.FileName
} catch {
    try {
        $raw = Get-Content -Encoding Default -Raw $dlg.FileName
    } catch {
        Write-Error ('Failed to read file: ' + $_.Exception.Message)
        exit 10
    }
}

# 改行除去し 1 行化
$oneLine = ($raw -replace "`r?`n",'')
$oneLine = $oneLine.Trim()

if ([string]::IsNullOrWhiteSpace($oneLine)) {
    Write-Error 'File content empty.'
    exit 11
}

# 形式簡易チェック（prefix）
$validPrefixes = @('ssh-ed25519','ssh-rsa','ecdsa-sha2-nistp256','sk-ssh-ed25519@openssh.com','sk-ecdsa-sha2-nistp256@openssh.com')
$prefixOk = $false
foreach ($p in $validPrefixes) {
    if ($oneLine.StartsWith($p)) { $prefixOk = $true; break }
}
if (-not $prefixOk) {
    Write-Warning '公開鍵形式が一般的な prefix と一致しません: ' + ($validPrefixes -join ', ')
}

# 出力
Write-Output $oneLine
exit 0
