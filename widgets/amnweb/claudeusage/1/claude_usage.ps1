param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('usage', 'history', 'status')]
    [string]$Operation,
    [int]$Interval = 120000,
    [string]$Refresh = 'cached'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$cacheHome = Join-Path $env:LOCALAPPDATA 'YASB\ClaudeUsage'
$usageUrl = 'https://api.anthropic.com/api/oauth/usage'
$statusUrl = 'https://status.claude.com/api/v2/status.json'
$invariant = [Globalization.CultureInfo]::InvariantCulture

function Read-Record($Path) {
    try { ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($Path)) }
    catch { $null }
}

function Save-Record($Path, $Value) {
    $temp = Join-Path $cacheHome ([Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $null = [IO.Directory]::CreateDirectory($cacheHome)
        [IO.File]::WriteAllText($temp, (ConvertTo-Json -InputObject $Value -Depth 16 -Compress))
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temp, $Path, [NullString]::Value) }
        else { [IO.File]::Move($temp, $Path) }
    } catch [IO.IOException] {
        # A second instance can update the cache first.
    } catch [UnauthorizedAccessException] {
        # The current result is still usable when the cache cannot be written.
    } finally {
        Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue
    }
}

function Get-ApiJson($Url, $Headers = @{}) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-RestMethod -Uri $Url -Headers $Headers -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 15
}

function Read-Date($Value) {
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($Value, $invariant, [Globalization.DateTimeStyles]::AssumeLocal, [ref]$parsed)) {
        $parsed
    }
}

function Convert-Limit($Entry, $Key, $Name) {
    if ($null -eq $Entry) { return }
    $percent = $Entry.utilization
    if ($null -eq $percent) { $percent = $Entry.percent }
    if ($percent -isnot [ValueType] -or $percent -is [bool]) { return }
    $reset = Read-Date $Entry.resets_at
    @{
        key = $Key
        name = $Name
        percent = $percent
        resetsAt = if ($reset) { $reset.ToUnixTimeMilliseconds() } else { 0 }
    }
}

function Get-Usage {
    $auth = (Read-Record (Join-Path $claudeHome '.credentials.json')).claudeAiOauth
    if ($auth.accessToken -isnot [string] -or -not $auth.accessToken.Trim()) {
        return @{ signedIn = $false; error = 'Sign in to Claude Code to see usage limits. Local token history is still available.' }
    }

    $path = Join-Path $cacheHome 'limits.json'
    $cached = Read-Record $path
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $renew = "Claude Code's sign-in has expired. Open Claude Code to renew it."
    $result = @{
        signedIn = $true
        expiresAt = if ($auth.expiresAt -is [ValueType] -and $auth.expiresAt -isnot [bool]) { [long]$auth.expiresAt } else { 0 }
        limits = if ($cached.limits) { @($cached.limits) } else { @() }
        fetchedAt = [long]$cached.fetchedAt
        error = ''
    }
    # Keep limits an array even when PowerShell unwraps a single result.
    $result.limits = @($result.limits | Where-Object { $null -ne $_ })
    if ($result.expiresAt -gt 0 -and $result.expiresAt -le $now) {
        $result.expired = $true
        $result.error = $renew
        return $result
    }
    $age = $now - $result.fetchedAt
    if ($Refresh -ne 'force' -and $age -ge 0 -and $age -lt $Interval) { return $result }

    try {
        $reply = Get-ApiJson $usageUrl @{
            Authorization = 'Bearer ' + $auth.accessToken.Trim()
            'anthropic-beta' = 'oauth-2025-04-20'
        }
        if ($reply -isnot [PSCustomObject]) { throw 'Expected a usage object.' }
    } catch {
        $code = [int]$_.Exception.Response.StatusCode
        $result.error = switch ($code) {
            401 { $result.expired = $true; $renew }
            429 { 'Anthropic is rate limiting usage requests. Showing the last available limits.' }
            0 { 'Could not read usage from Anthropic.' }
            default { "Anthropic returned HTTP $code." }
        }
        return $result
    }

    $result.limits = @(
        Convert-Limit $reply.five_hour 'five_hour' '5-hour'
        Convert-Limit $reply.seven_day 'seven_day' '7-day'
        foreach ($limit in $reply.limits) {
            $name = $limit.scope.model.display_name
            if ($limit.kind -eq 'weekly_scoped' -and $name -is [string] -and $name) {
                Convert-Limit $limit 'model' $name
            }
        }
    )
    $result.fetchedAt = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    Save-Record $path @{ limits = $result.limits; fetchedAt = $result.fetchedAt }
    $result
}

function Add-Counts($Map, $Key, $Counts) {
    if (-not $Map.ContainsKey($Key)) { $Map[$Key] = [long[]]::new(4) }
    $target = $Map[$Key]
    for ($index = 0; $index -lt 4; $index++) { $target[$index] += $Counts[$index] }
}

function Read-HistoryLog($Path, $Cutoff) {
    $groups = @{}
    $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, $share)
    $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line -notmatch '"usage"\s*:') { continue }
            try {
                $entry = ConvertFrom-Json -InputObject $line
                $counts = $entry.message.usage
                if (-not $counts) { continue }
                $stamp = Read-Date $entry.timestamp
                if (-not $stamp -or $stamp.LocalDateTime -lt $Cutoff) { continue }
                $values = [long[]]@($counts.input_tokens, $counts.output_tokens,
                    $counts.cache_creation_input_tokens, $counts.cache_read_input_tokens)
                if (-not ($values[0] -or $values[1] -or $values[2] -or $values[3])) { continue }
            } catch { continue }

            $hour = $stamp.LocalDateTime.ToString('yyyy-MM-ddTHH', $invariant)
            $model = if ($entry.message.model -is [string] -and $entry.message.model) { $entry.message.model } else { 'unknown' }
            if ($counts.speed -eq 'fast') { $model += '[fast]' }
            $session = if ($entry.sessionId -is [string] -and $entry.sessionId) { $entry.sessionId } else { 'unknown' }
            $key = @($hour, $model, $session) -join [char]10
            if (-not $groups.ContainsKey($key)) {
                $groups[$key] = @{ hour = $hour; model = $model; session = $session; last = 0; counts = [long[]]::new(4) }
            }
            $group = $groups[$key]
            $group.last = [Math]::Max([long]$group.last, $stamp.ToUnixTimeMilliseconds())
            for ($index = 0; $index -lt 4; $index++) { $group.counts[$index] += $values[$index] }
        }
    } finally { $reader.Dispose() }
    $groups.Values
}

function Get-History {
    $now = [DateTime]::Today
    $today = $now.ToString('yyyy-MM-dd', $invariant)
    $cutoff = $now.AddDays(-400)
    $sessionCutoff = $now.AddDays(-14).ToString('yyyy-MM-ddTHH', $invariant)
    $path = Join-Path $cacheHome 'token-history.json'
    $cache = Read-Record $path
    $known = @{}
    if ($cache.version -eq 5) {
        foreach ($record in $cache.files) { $known[$record.path] = $record }
    }
    $files = [Collections.Generic.List[object]]::new()
    $days = @{}
    $hours = @{}
    $latest = $null
    $changed = $false
    $projects = Join-Path $claudeHome 'projects'
    foreach ($log in (Get-ChildItem -LiteralPath $projects -Filter '*.jsonl' -File -Recurse -ErrorAction SilentlyContinue)) {
        if ($log.LastWriteTime -lt $cutoff) { continue }
        $stamp = $log.LastWriteTimeUtc.Ticks
        $record = $known[$log.FullName]
        if (-not $record -or $record.stamp -ne $stamp -or $record.size -ne $log.Length) {
            try { $rows = @(Read-HistoryLog $log.FullName $cutoff) }
            catch [IO.IOException] { continue }
            catch [UnauthorizedAccessException] { continue }
            $record = @{ path = $log.FullName; stamp = $stamp; size = $log.Length; rows = $rows }
            $changed = $true
        }
        $files.Add($record)
        foreach ($row in $record.rows) {
            $day = $row.hour.Substring(0, 10)
            if (-not $days.ContainsKey($day)) { $days[$day] = @{} }
            Add-Counts $days[$day] $row.model $row.counts
            if ($day -eq $today) { Add-Counts $hours $row.hour $row.counts }
            if (-not $latest -or $row.last -gt $latest.last) { $latest = $row }
        }
    }
    if ($changed -or $files.Count -ne $known.Count) {
        Save-Record $path @{ version = 5; files = $files.ToArray() }
    }

    $session = @{ models = @{}; hours = @{} }
    if ($latest) {
        foreach ($record in $files) {
            foreach ($row in $record.rows) {
                if ($row.session -ne $latest.session) { continue }
                Add-Counts $session.models $row.model $row.counts
                if ($row.hour -ge $sessionCutoff) { Add-Counts $session.hours $row.hour $row.counts }
            }
        }
    }
    @{ days = $days; hours = $hours; session = $session }
}

try {
    $result = switch ($Operation) {
        'usage' { Get-Usage }
        'history' { Get-History }
        'status' { (Get-ApiJson $statusUrl).status }
    }
    ConvertTo-Json -InputObject $result -Depth 16 -Compress
} catch {
    # Never emit an HTTP exception or a malformed credential record into the bar.
    [Console]::Error.WriteLine("Could not read Claude $Operation.")
    exit 1
}
