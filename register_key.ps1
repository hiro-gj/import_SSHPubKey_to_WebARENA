$sshKeyClean = ($env:sshKey -split ' ' | Select-Object -First 2) -join ' '
$body = @{
    sshName = $env:sshName
    sshKey  = $sshKeyClean
}

$maxAttempts = 5
if ($env:SSH_API_MAX_RETRY -match '^\d+$' -and [int]$env:SSH_API_MAX_RETRY -gt 0) {
    $maxAttempts = [int]$env:SSH_API_MAX_RETRY
}

$baseDelay = 2
if ($env:SSH_API_BASE_DELAY -match '^\d+$' -and [int]$env:SSH_API_BASE_DELAY -gt 0) {
    $baseDelay = [int]$env:SSH_API_BASE_DELAY
}

for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    Write-Host ("[DBG][TRY] attempt {0}/{1}" -f $attempt, $maxAttempts)
    try {
        $reqJson = ($body | ConvertTo-Json -Compress)
        Write-Host ("[DBG] request json=" + $reqJson)
        $response = Invoke-RestMethod -Method Post -Uri $env:sshKeyEndpoint -Headers @{ Authorization = 'Bearer ' + $env:accessToken } -Body $reqJson -ContentType 'application/json'
        if ($response) {
            Write-Host "[DBG] response json:"
            $response | ConvertTo-Json -Depth 10
        } else {
            Write-Host "[DBG] empty response"
        }
        exit 0
    } catch {
        $statusCode = $null
        if ($_.Exception -and $_.Exception.PSObject.Properties.Name -contains 'Response' -and $_.Exception.Response) {
            try {
                $statusCode = [int]$_.Exception.Response.StatusCode
            } catch {
                try { $statusCode = [int]$_.Exception.Response.StatusCode.value__ } catch { }
            }
        }

        Write-Host ('ERROR: ' + $_.Exception.Message)
        if ($_.Exception.Response) {
            try {
                $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errBody = $sr.ReadToEnd()
                if ($errBody) {
                    Write-Host "[DBG] error response body raw:"
                    Write-Host $errBody
                    try {
                        $parsed = $errBody | ConvertFrom-Json -ErrorAction Stop
                        Write-Host "[DBG] error response body (formatted JSON):"
                        $parsed | ConvertTo-Json -Depth 10
                    } catch { }
                }
            } catch { }
        }
        if ($statusCode -ne $null) {
            Write-Host ("[DBG] statusCode=" + $statusCode)
        }
        if ($_.ScriptStackTrace) {
            Write-Host $_.ScriptStackTrace
        }

        $shouldRetry = ($statusCode -eq 429) -or ($statusCode -ge 500 -and $statusCode -lt 600)
        if ($shouldRetry -and $attempt -lt $maxAttempts) {
            $displayStatus = 'unknown'
            if ($statusCode -ne $null) {
                $displayStatus = $statusCode
            }
            $delay = [math]::Min(60, $baseDelay * [math]::Pow(2, $attempt - 1))
            $delaySeconds = [int][math]::Ceiling($delay)
            Write-Host ("[DBG][RETRY] status={0} wait={1}s before retry" -f $displayStatus, $delaySeconds)
            Start-Sleep -Seconds $delaySeconds
            continue
        }

        exit 1
    }
}

Write-Host "[DBG][ERR] max retry attempts reached"
exit 1
