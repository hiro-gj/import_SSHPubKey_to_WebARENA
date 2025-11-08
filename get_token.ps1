# Load .env into process environment variables (ignore comment lines)
$envFile = Join-Path (Get-Location) '.env'
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $parts = $line -split '=', 2
            if ($parts.Length -eq 2) {
                [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), 'Process')
            }
        }
    }
}

# Request body (preserve original behavior)
$body = @{
    grantType    = 'client_credentials'
    clientId     = $env:clientId
    clientSecret = $env:clientSecret
    code         = ''
}

try {
    # Show JSON to be sent for debugging (write to stderr so calling batch files don't treat output as commands)
    $json = $body | ConvertTo-Json -Depth 5
    [Console]::Error.WriteLine("DEBUG: Request JSON:")
    [Console]::Error.WriteLine($json)

    # Execute request (stop on error)
    $response = Invoke-RestMethod -Method Post -Uri 'https://api.customer.jp/oauth/v1/accesstokens' -Body $json -ContentType 'application/json' -ErrorAction Stop

    # Debug: show full response object (to stderr)
    [Console]::Error.WriteLine("DEBUG: Raw response object:")
    [Console]::Error.WriteLine(($response | ConvertTo-Json -Depth 5))

    $accessToken = $response.accessToken

    if (-not $accessToken) {
        Write-Host 'ERROR: accessToken not found in response.'
        exit 1
    }

    Write-Output "set accessToken=$accessToken"
} catch {
    [Console]::Error.WriteLine("ERROR: " + $_.Exception.Message)
    # If HTTP response content is available, output it to stderr
    if ($_.Exception.Response -and $_.Exception.Response.Content) {
        try {
            $errContent = $_.Exception.Response.Content | ConvertFrom-Json
            [Console]::Error.WriteLine("ERROR RESPONSE: " + ($errContent | ConvertTo-Json -Depth 5))
        } catch {
            [Console]::Error.WriteLine("ERROR RESPONSE (raw): " + $_.Exception.Response.Content)
        }
    }
    exit 1
}
