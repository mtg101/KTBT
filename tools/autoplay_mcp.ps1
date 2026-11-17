# KTBT autoplay helper: a tiny local MCP server for the Claude desktop app, so Claude can start
# and check a batch of autoplay nights (see scripts/autoplay.gd) while nobody's at the PC.
# It can do three things and nothing else: start a batch (Godot with --autoplay, in this
# project only), say how one's going (and whether Ollama answers), and stop one. No general
# shell, no other programs. Plain PowerShell, so nothing to install.
#
# Set up once (TOOLCHAIN.md, "Autoplay from your phone"): add it to the desktop app's local MCP
# servers, with powershell.exe -NoProfile -ExecutionPolicy Bypass -File <this file>.
# MCP over stdio: one JSON message per line in and out. Only JSON goes to stdout; notes go to
# stderr.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot  # the project folder (this file's in tools\)
$MostNights = 30

try {
	[Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
	[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
} catch { }  # (some hosts won't change it: the messages are ASCII-safe JSON anyway)

function Note([string]$text) { [Console]::Error.WriteLine("ktbt-autoplay: $text") }

function Send($message) {
	$json = $message | ConvertTo-Json -Depth 20 -Compress
	[Console]::Out.WriteLine($json)
	[Console]::Out.Flush()
}

function Reply($id, $result) { Send ([ordered]@{ jsonrpc = '2.0'; id = $id; result = $result }) }

function ReplyError($id, [int]$code, [string]$text) {
	Send ([ordered]@{ jsonrpc = '2.0'; id = $id; error = [ordered]@{ code = $code; message = $text } })
}

function ToolText([string]$text, [bool]$isError = $false) {
	return [ordered]@{ content = @([ordered]@{ type = 'text'; text = $text }); isError = $isError }
}

# --- What it can do ----------------------------------------------------------------------

function GodotPath {
	$file = Join-Path $PSScriptRoot 'godot_path.txt'
	if (-not (Test-Path $file)) { return $null }
	$path = (Get-Content -Path $file -TotalCount 1).Trim().Trim('"')
	if ($path -eq '' -or -not (Test-Path $path -PathType Leaf)) { return $null }
	return $path
}

function RunningBatches {
	return @(Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" |
		Where-Object { $_.CommandLine -and $_.CommandLine -match '--autoplay=' })
}

function OllamaAnswers {
	try {
		$reply = Invoke-WebRequest -Uri 'http://localhost:11434' -UseBasicParsing -TimeoutSec 3
		return $reply.Content -match 'Ollama is running'
	} catch { return $false }
}

function NewestSummary {
	$folder = Join-Path $Root 'logs\autoplay'
	if (-not (Test-Path $folder)) { return $null }
	return Get-ChildItem -Path $folder -Filter '*.txt' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function StartBatch($arguments) {
	$nights = 10
	if ($null -ne $arguments -and $null -ne $arguments.nights) { $nights = [int]$arguments.nights }
	if ($nights -lt 1 -or $nights -gt $MostNights) { return ToolText "nights must be from 1 to $MostNights." $true }
	$bar = ''
	if ($null -ne $arguments -and $null -ne $arguments.bar_id) { $bar = [string]$arguments.bar_id }
	if ($bar -ne '' -and $bar -notmatch '^[A-Za-z0-9-]{1,80}$') { return ToolText 'bar_id can only have letters, digits and hyphens.' $true }
	if ((RunningBatches).Count -gt 0) { return ToolText 'A batch is already running: check on it, or stop it first.' $true }
	$godot = GodotPath
	if ($null -eq $godot) { return ToolText "Can't find Godot: put the full path of its .exe on one line in tools\godot_path.txt." $true }
	if (-not (OllamaAnswers)) { return ToolText "Ollama isn't answering at localhost:11434: start it on the PC first (the nights would only be offline ones)." $true }
	$godotArgs = @('--path', "`"$Root`"", '--', "--autoplay=$nights")
	if ($bar -ne '') { $godotArgs += "--autoplay-bar=$bar" }
	Start-Process -FilePath $godot -ArgumentList $godotArgs -WorkingDirectory $Root | Out-Null
	Note "started $nights nights"
	$which = 'in a bar of its own'
	if ($bar -ne '') { $which = "carrying on bar $bar" }
	return ToolText "Started: $nights nights, $which. A night takes about 4 minutes (longer with Reading pauses on); the summary in logs\autoplay is written after every night."
}

function Status {
	$lines = @()
	$running = RunningBatches
	if ($running.Count -gt 0) { $lines += "A batch is running (started $($running[0].CreationDate))." } else { $lines += 'No batch is running.' }
	if (OllamaAnswers) { $lines += 'Ollama is answering.' } else { $lines += "Ollama isn't answering at localhost:11434." }
	$summary = NewestSummary
	if ($null -ne $summary) {
		$lines += ''
		$lines += "Newest summary ($($summary.Name), written $($summary.LastWriteTime)):"
		$lines += (Get-Content -Path $summary.FullName -Raw -Encoding UTF8)
	} else {
		$lines += 'No autoplay summary yet.'
	}
	return ToolText ($lines -join "`n")
}

function StopBatch {
	$running = RunningBatches
	if ($running.Count -eq 0) { return ToolText 'No batch is running.' }
	foreach ($process in $running) { Stop-Process -Id $process.ProcessId -Force }
	return ToolText "Stopped. The bar's saved after every visit, so it carries on from there; tonight's log for the night it was in stops where it was."
}

$Tools = @(
	[ordered]@{ name = 'start_autoplay'; description = 'Start a batch of KTBT nights that play themselves with the real AI (Ollama) on this PC. A night takes about 4 minutes (longer with Reading pauses on).'
		inputSchema = [ordered]@{ type = 'object'; properties = [ordered]@{
			nights = [ordered]@{ type = 'integer'; minimum = 1; maximum = $MostNights; description = 'How many nights (default 10).' }
			bar_id = [ordered]@{ type = 'string'; description = "Optional: a saved bar's id, to carry it on rather than start a new one." } } } },
	[ordered]@{ name = 'autoplay_status'; description = "Whether a batch is running, whether Ollama's answering, and the newest batch summary."
		inputSchema = [ordered]@{ type = 'object'; properties = [ordered]@{} } },
	[ordered]@{ name = 'stop_autoplay'; description = 'Stop the running batch.'
		inputSchema = [ordered]@{ type = 'object'; properties = [ordered]@{} } }
)

# --- The conversation with the app ----------------------------------------------------------

Note "ready (project: $(Split-Path -Leaf $Root))"
while ($true) {
	$line = [Console]::In.ReadLine()
	if ($null -eq $line) { break }  # (the app closed it)
	if ($line.Trim() -eq '') { continue }
	try { $message = $line | ConvertFrom-Json } catch { Note "not JSON: $line"; continue }
	$hasId = $null -ne $message.PSObject.Properties['id']
	if (-not $hasId) { continue }  # (a notification: nothing to answer)
	$id = $message.id
	try {
		switch ([string]$message.method) {
			'initialize' {
				$version = '2025-06-18'
				if ($null -ne $message.params -and $message.params.protocolVersion) { $version = [string]$message.params.protocolVersion }
				Reply $id ([ordered]@{ protocolVersion = $version; capabilities = [ordered]@{ tools = [ordered]@{} }
					serverInfo = [ordered]@{ name = 'ktbt-autoplay'; version = '1.0.0' } })
			}
			'ping' { Reply $id ([ordered]@{}) }
			'tools/list' { Reply $id ([ordered]@{ tools = $Tools }) }
			'tools/call' {
				$arguments = $message.params.arguments
				$result = switch ([string]$message.params.name) {
					'start_autoplay' { StartBatch $arguments }
					'autoplay_status' { Status }
					'stop_autoplay' { StopBatch }
					default { ToolText "No such tool: $($message.params.name)" $true }
				}
				Reply $id $result
			}
			default { ReplyError $id -32601 "Method not found: $($message.method)" }
		}
	} catch {
		Note "error: $_"
		Reply $id (ToolText "Something went wrong: $_" $true)
	}
}
