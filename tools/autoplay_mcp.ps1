# KTBT autoplay helper: a tiny local MCP server for the Claude desktop app, so Claude can start
# and check a batch of autoplay nights (see scripts/autoplay.gd) while nobody's at the PC.
# It can do these things and nothing else: start a batch (Godot with --autoplay, in this
# project only), say how one's going (and whether Ollama answers), and stop one; and ask
# ComfyUI on this PC for pictures for the art (into art\raw\). No general shell, no other
# programs. Plain PowerShell, so nothing to install.
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

# The running batch, from the file the game keeps while one's going (logs\autoplay\running.json:
# its process id, nights, nights played, when it started, the bar), or $null. A file left by a
# batch that was killed (its process gone) is cleared.
function RunningBatch {
	$file = Join-Path $Root 'logs\autoplay\running.json'
	if (-not (Test-Path $file)) { return $null }
	try { $info = Get-Content -Path $file -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
	$process = Get-Process -Id ([int]$info.pid) -ErrorAction SilentlyContinue
	if ($null -eq $process -or $process.ProcessName -notlike 'Godot*') {
		Remove-Item -Path $file -ErrorAction SilentlyContinue
		return $null
	}
	return $info
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
	if ($null -ne (RunningBatch)) { return ToolText 'A batch is already running: check on it, or stop it first.' $true }
	$godot = GodotPath
	if ($null -eq $godot) { return ToolText "Can't find Godot: put the full path of its .exe on one line in tools\godot_path.txt." $true }
	if (-not (OllamaAnswers)) { return ToolText "Ollama isn't answering at localhost:11434: start it on the PC first (the nights would only be offline ones)." $true }
	$freed = StopComfy  # (the GPU's Ollama's while the nights play)
	$godotArgs = @('--path', "`"$Root`"", '--audio-driver', 'Dummy', '--', "--autoplay=$nights")  # (no sound: Windows' audio driver only adds errors)
	if ($bar -ne '') { $godotArgs += "--autoplay-bar=$bar" }
	Start-Process -FilePath $godot -ArgumentList $godotArgs -WorkingDirectory $Root | Out-Null
	Note "started $nights nights"
	$which = 'in a bar of its own'
	if ($bar -ne '') { $which = "carrying on bar $bar" }
	if ($freed) { $which += ' (ComfyUI stopped first, to free the GPU)' }
	return ToolText "Started: $nights nights, $which. A night takes about 4 minutes (longer with Reading pauses on); the summary in logs\autoplay is written after every night."
}

function Status {
	$lines = @()
	$running = RunningBatch
	if ($null -ne $running) {
		$bar = ''
		if ([string]$running.bar -ne '') { $bar = " at $($running.bar)" }
		$lines += "A batch is running$($bar): night $([int]$running.played + 1) of $($running.nights), started $($running.started)."
	} else { $lines += 'No batch is running.' }
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
	$running = RunningBatch
	if ($null -eq $running) { return ToolText 'No batch is running.' }
	Stop-Process -Id ([int]$running.pid) -Force
	Remove-Item -Path (Join-Path $Root 'logs\autoplay\running.json') -ErrorAction SilentlyContinue
	return ToolText "Stopped. The bar's saved after every visit, so it carries on from there; tonight's log for the night it was in stops where it was."
}

# --- Art: pictures from ComfyUI (ART.md, "Where the art comes from") ------------------------
# ComfyUI on this PC (127.0.0.1:8188; started in the background when it's needed, from the
# folder in tools\comfyui_path.txt, and stopped by stop_art or before autoplay nights), with
# the workflow saved from it in API form as tools\art\klein_api.json. A picture's prompt, seed and size go in; it lands in
# art\raw\ (not in git) with a note of how it was made, for the pixelate tool. Never while a
# batch is running (Ollama has the GPU).

$ComfyUrl = 'http://127.0.0.1:8188'
$MostPictures = 4

# ComfyUI's folder on this PC (the portable one, with run_nvidia_gpu.bat in it), from
# tools\comfyui_path.txt (one line; this PC's own, so not in git), or $null.
function ComfyFolder {
	$file = Join-Path $PSScriptRoot 'comfyui_path.txt'
	if (-not (Test-Path $file)) { return $null }
	$path = (Get-Content -Path $file -TotalCount 1).Trim().Trim('"').TrimEnd('\')
	if ($path -eq '' -or -not (Test-Path (Join-Path $path 'python_embeded\python.exe'))) { return $null }
	return $path
}

# ComfyUI's own processes (its embedded Python), however it was started.
function ComfyProcesses {
	$folder = ComfyFolder
	if ($null -eq $folder) { return @() }
	return @(Get-Process -Name 'python*' -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path -like "$folder\*" })
}

# Starts ComfyUI in the background (no window, no browser; its output in logs\comfyui.log) and
# waits for it to answer. '' when it's answering, otherwise why not.
function StartComfy {
	if (ComfyAnswers) { return '' }
	$folder = ComfyFolder
	if ($null -eq $folder) { return "Can't find ComfyUI: put its folder (the one with run_nvidia_gpu.bat) on one line in tools\comfyui_path.txt." }
	if (@(ComfyProcesses).Count -eq 0) {
		$logs = Join-Path $Root 'logs'
		if (-not (Test-Path $logs)) { New-Item -ItemType Directory -Path $logs | Out-Null }
		$python = Join-Path $folder 'python_embeded\python.exe'
		$comfyArgs = @('-s', 'ComfyUI\main.py', '--windows-standalone-build', '--disable-auto-launch')
		Start-Process -FilePath $python -ArgumentList $comfyArgs -WorkingDirectory $folder -WindowStyle Hidden `
			-RedirectStandardOutput (Join-Path $logs 'comfyui.log') -RedirectStandardError (Join-Path $logs 'comfyui_errors.log') | Out-Null
		Note 'started ComfyUI'
	}
	for ($wait = 0; $wait -lt 25; $wait++) {  # (it takes 10 to 30 seconds to start)
		Start-Sleep -Seconds 2
		if (ComfyAnswers) { return '' }
	}
	return "ComfyUI is starting (or stuck: see logs\comfyui_errors.log). Try again in a minute."
}

# Stops ComfyUI, to give the GPU back. Whether it was running.
function StopComfy {
	$running = @(ComfyProcesses)
	foreach ($process in $running) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
	if ($running.Count -gt 0) { Note 'stopped ComfyUI' }
	return $running.Count -gt 0
}

function StopArt {
	if (StopComfy) { return ToolText 'Stopped ComfyUI: the GPU is free for Ollama.' }
	if (ComfyAnswers) { return ToolText "ComfyUI is answering but wasn't started from tools\comfyui_path.txt's folder: close its window on the PC." $true }
	return ToolText "ComfyUI wasn't running."
}

function ComfyAnswers {
	try { Invoke-WebRequest -Uri "$ComfyUrl/system_stats" -UseBasicParsing -TimeoutSec 3 | Out-Null; return $true } catch { return $false }
}

function RawFolder {
	$folder = Join-Path $Root 'art\raw'
	if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
	return $folder
}

# The pictures still being made: art\raw\pending.json, [{prompt_id, name, seed, prompt, width, height}].
function Pending {
	$file = Join-Path (RawFolder) 'pending.json'
	if (-not (Test-Path $file)) { return @() }
	try { return @(Get-Content -Path $file -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return @() }
}

function SavePending($items) {
	$file = Join-Path (RawFolder) 'pending.json'
	if (@($items).Count -eq 0) { Remove-Item -Path $file -ErrorAction SilentlyContinue; return }
	ConvertTo-Json -InputObject @($items) -Depth 5 | Set-Content -Path $file -Encoding UTF8
}

# Fetches whatever's finished: saved as art\raw\<name>_<seed>.png, with <name>_<seed>.json saying
# how it was made. Returns the lines to report; the unfinished stay pending.
function Collect {
	$lines = @()
	$still = @()
	foreach ($item in (Pending)) {
		$history = $null
		try { $history = Invoke-RestMethod -Uri "$ComfyUrl/history/$($item.prompt_id)" -TimeoutSec 5 } catch { }
		$entry = $null
		if ($null -ne $history) { $entry = $history.PSObject.Properties[[string]$item.prompt_id] }
		if ($null -eq $entry) { $still += $item; continue }
		$saved = $false
		foreach ($node in $entry.Value.outputs.PSObject.Properties) {
			foreach ($image in @($node.Value.images)) {
				if ($null -eq $image -or $saved) { continue }
				$base = "$($item.name)_$($item.seed)"
				$path = Join-Path (RawFolder) "$base.png"
				$query = "filename=$([uri]::EscapeDataString([string]$image.filename))&subfolder=$([uri]::EscapeDataString([string]$image.subfolder))&type=$($image.type)"
				Invoke-WebRequest -Uri "$ComfyUrl/view?$query" -OutFile $path -UseBasicParsing -TimeoutSec 30
				$note = [ordered]@{ model = 'FLUX.2 Klein 4B (fp8), Apache 2.0'; workflow = 'tools/art/klein_api.json'; prompt = $item.prompt
					seed = $item.seed; width = $item.width; height = $item.height; made = (Get-Date -Format 's') }
				ConvertTo-Json -InputObject $note | Set-Content -Path (Join-Path (RawFolder) "$base.json") -Encoding UTF8
				$lines += "art\raw\$base.png"
				$saved = $true
			}
		}
		if (-not $saved) { $lines += "$($item.name) (seed $($item.seed)): finished without a picture (see ComfyUI's window)" }
	}
	SavePending $still
	if ($still.Count -gt 0) { $lines += "Still being made: $($still.Count) (collect_art fetches them)." }
	return $lines
}

function GenerateArt($arguments) {
	if ($null -eq $arguments -or [string]$arguments.prompt -eq '') { return ToolText 'A prompt is needed.' $true }
	$prompt = [string]$arguments.prompt
	if ($prompt.Length -gt 1500) { return ToolText 'The prompt is too long (1500 characters at most).' $true }
	$name = [string]$arguments.name
	if ($name -notmatch '^[a-z0-9_-]{1,60}$') { return ToolText 'name: lowercase letters, digits, - and _ only (it names the files).' $true }
	$count = 1
	if ($null -ne $arguments.count) { $count = [int]$arguments.count }
	if ($count -lt 1 -or $count -gt $MostPictures) { return ToolText "count must be from 1 to $MostPictures." $true }
	$width = 1024; $height = 1024
	if ($null -ne $arguments.width) { $width = [int]$arguments.width }
	if ($null -ne $arguments.height) { $height = [int]$arguments.height }
	foreach ($size in @($width, $height)) {
		if ($size -lt 256 -or $size -gt 1536 -or $size % 16 -ne 0) { return ToolText 'width and height: 256 to 1536, in steps of 16.' $true }
	}
	$seed = Get-Random -Minimum 1 -Maximum 2000000000
	if ($null -ne $arguments.seed) { $seed = [int]$arguments.seed }
	if ($null -ne (RunningBatch)) { return ToolText "An autoplay batch is running: Ollama has the GPU. Stop it first, or wait." $true }
	$problem = StartComfy
	if ($problem -ne '') { return ToolText $problem $true }
	$workflowFile = Join-Path $PSScriptRoot 'art\klein_api.json'
	if (-not (Test-Path $workflowFile)) { return ToolText "No workflow: in ComfyUI, Workflow > Export (API), saved as tools\art\klein_api.json." $true }
	$pending = @(Pending)
	for ($k = 0; $k -lt $count; $k++) {
		$workflow = Get-Content -Path $workflowFile -Raw -Encoding UTF8 | ConvertFrom-Json
		$prompted = $false
		foreach ($node in $workflow.PSObject.Properties) {
			$inputs = $node.Value.inputs
			if ($null -eq $inputs) { continue }
			$type = [string]$node.Value.class_type
			$title = [string]$node.Value._meta.title
			if ($type -like 'CLIPTextEncode*' -and $null -ne $inputs.PSObject.Properties['text'] -and $title -notmatch 'Negative' -and -not $prompted) {
				$inputs.text = $prompt; $prompted = $true
			}
			foreach ($field in @('seed', 'noise_seed')) {
				if ($null -ne $inputs.PSObject.Properties[$field] -and $inputs.$field -isnot [array]) { $inputs.$field = $seed + $k }
			}
			if ($null -ne $inputs.PSObject.Properties['width'] -and $null -ne $inputs.PSObject.Properties['height'] -and $inputs.width -isnot [array]) {
				$inputs.width = $width; $inputs.height = $height
			}
			if ($type -eq 'PrimitiveInt' -and $title -eq 'Width') { $inputs.value = $width }  # (the Klein template's size boxes)
			if ($type -eq 'PrimitiveInt' -and $title -eq 'Height') { $inputs.value = $height }
			if ($type -eq 'SaveImage') { $inputs.filename_prefix = "ktbt/$name" }
		}
		if (-not $prompted) { return ToolText "The workflow has no prompt box (a CLIPTextEncode node) to fill in." $true }
		$body = ConvertTo-Json -InputObject ([ordered]@{ prompt = $workflow; client_id = 'ktbt-autoplay' }) -Depth 50 -Compress
		$queued = Invoke-RestMethod -Uri "$ComfyUrl/prompt" -Method Post -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json' -TimeoutSec 15
		$pending += [ordered]@{ prompt_id = [string]$queued.prompt_id; name = $name; seed = $seed + $k; prompt = $prompt; width = $width; height = $height }
	}
	SavePending $pending
	Note "queued $count pictures: $name"
	$lines = @()
	for ($wait = 0; $wait -lt 20; $wait++) {  # (about 40 seconds, inside the app's patience; then collect_art carries on)
		Start-Sleep -Seconds 2
		$lines = @(@($lines) + @(Collect) | Where-Object { $_ -notlike 'Still being made*' })
		if (@(Pending).Count -eq 0) { break }
	}
	$left = @(Pending).Count
	if ($left -gt 0) { $lines += "Still being made: $left (collect_art fetches them)." }
	return ToolText ("Made with seed $seed (then +1 each):`n" + ($lines -join "`n"))
}

function CollectArt {
	if (@(Pending).Count -eq 0) { return ToolText 'Nothing being made.' }
	if (-not (ComfyAnswers)) { return ToolText "ComfyUI isn't answering at $($ComfyUrl)." $true }
	$lines = @(Collect)
	if ($lines.Count -eq 0) { $lines = @('Nothing finished yet.') }
	return ToolText ($lines -join "`n")
}

$Tools = @(
	[ordered]@{ name = 'start_autoplay'; description = 'Start a batch of KTBT nights that play themselves with the real AI (Ollama) on this PC. A night takes about 4 minutes (longer with Reading pauses on).'
		inputSchema = [ordered]@{ type = 'object'; properties = [ordered]@{
			nights = [ordered]@{ type = 'integer'; minimum = 1; maximum = $MostNights; description = 'How many nights (default 10).' }
			bar_id = [ordered]@{ type = 'string'; description = "Optional: a saved bar's id, to carry it on rather than start a new one." } } } },
	[ordered]@{ name = 'autoplay_status'; description = "Whether a batch is running, whether Ollama's answering, and the newest batch summary."
		inputSchema = [ordered]@{ type = 'object'; properties = [ordered]@{} } },
	[ordered]@{ name = 'stop_autoplay'; description = 'Stop the running batch.'
		inputSchema = [ordered]@{ type = 'object'; properties = [ordered]@{} } },
	[ordered]@{ name = 'generate_art'; description = "Make pictures for KTBT's art with the image model (FLUX.2 Klein 4B in ComfyUI on this PC, started in the background if it isn't running), into art\raw\ with a note of how each was made, for the pixelate tool. Not while an autoplay batch is running. Waits about 40 seconds; collect_art fetches any still being made."
		inputSchema = [ordered]@{ type = 'object'; required = @('prompt', 'name'); properties = [ordered]@{
			prompt = [ordered]@{ type = 'string'; description = 'What to draw: one thing, on a flat green background (magenta for something green), no text.' }
			name = [ordered]@{ type = 'string'; description = 'Names the files: lowercase, digits, - and _ (e.g. lucky_cat).' }
			count = [ordered]@{ type = 'integer'; minimum = 1; maximum = $MostPictures; description = 'How many (default 1), each with the next seed.' }
			seed = [ordered]@{ type = 'integer'; description = 'Optional: the seed, to make one again or vary it.' }
			width = [ordered]@{ type = 'integer'; description = 'Pixels, 256 to 1536 in steps of 16 (default 1024).' }
			height = [ordered]@{ type = 'integer'; description = 'Pixels, 256 to 1536 in steps of 16 (default 1024).' } } } },
	[ordered]@{ name = 'collect_art'; description = 'Fetch any pictures generate_art was still making.'
		inputSchema = [ordered]@{ type = 'object'; properties = [ordered]@{} } },
	[ordered]@{ name = 'stop_art'; description = 'Stop ComfyUI, to give the GPU back (start_autoplay does this itself).'
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
					'generate_art' { GenerateArt $arguments }
					'collect_art' { CollectArt }
					'stop_art' { StopArt }
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
