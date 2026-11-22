# KTBT autoplay helper: a tiny local MCP server for the Claude desktop app, so Claude can start
# and check a batch of autoplay nights (see scripts/autoplay.gd) while nobody's at the PC.
# It can do these things and nothing else: start a batch (Godot with --autoplay, in this
# project only), say how one's going (and whether Ollama answers), and stop one; and ask
# ComfyUI on this PC for pictures for the art (into art\raw\, one at a time or a batch from a list); and import the project's new
# or changed art and fonts (Godot's own --import, so the game and the tests see them without
# opening the editor). No general shell, no other programs. Plain PowerShell, so nothing to install.
#
# Set up once (TOOLCHAIN.md, "Autoplay from your phone"): add it to the desktop app's local MCP
# servers, with powershell.exe -NoProfile -ExecutionPolicy Bypass -File <this file>.
# MCP over stdio: one JSON message per line in and out. Only JSON goes to stdout; notes go to
# stderr.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot  # the project folder (this file's in tools\)
$MostNights = 30
$CollectAtMost = 60  # (pictures fetched in one collect_art: a batch's hundreds would outlast the app's patience)

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

# Godot's console build beside it, if there is one (its output can be read); else Godot itself.
function GodotConsolePath {
	$godot = GodotPath
	if ($null -eq $godot) { return $null }
	$console = $godot -replace '\.exe$', '_console.exe'
	if ($console -ne $godot -and (Test-Path $console -PathType Leaf)) { return $console }
	return $godot
}

# Imports new and changed assets (art, fonts) the way the editor does when it opens, then quits:
# so the game and the tests see art changed outside the editor. Returns a note of how it went
# (and any errors), or $null if Godot can't be found.
function ImportAssets {
	$godot = GodotConsolePath
	if ($null -eq $godot) { return $null }
	$out = Join-Path $env:TEMP 'ktbt_import_out.txt'
	$err = Join-Path $env:TEMP 'ktbt_import_err.txt'
	$process = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', "`"$Root`"", '--import') -WorkingDirectory $Root `
		-WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
	if (-not $process.WaitForExit(180000)) {
		try { $process.Kill() } catch { }
		return 'The import took over 3 minutes and was stopped.'
	}
	$lines = @()
	foreach ($file in @($out, $err)) {
		if (Test-Path $file) { $lines += Get-Content -Path $file -Encoding UTF8 }
	}
	$problems = @($lines | Where-Object { $_ -match 'ERROR|WARNING|Error' } | Select-Object -First 12)
	if ($problems.Count -eq 0) { return 'Imported: the art and fonts are up to date.' }
	return "Imported, with these messages:`n" + ($problems -join "`n")
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
	$listed = @(Pending).Count
	$freed = StopComfy  # (the GPU's Ollama's while the nights play)
	$forgot = ''
	if ($freed) { $forgot = ForgetPending $listed }  # (its queue went with it)
	$null = ImportAssets  # (any art changed since the editor last looked: the nights use it)
	$godotArgs = @('--path', "`"$Root`"", '--audio-driver', 'Dummy', '--', "--autoplay=$nights")  # (no sound: Windows' audio driver only adds errors)
	if ($bar -ne '') { $godotArgs += "--autoplay-bar=$bar" }
	Start-Process -FilePath $godot -ArgumentList $godotArgs -WorkingDirectory $Root | Out-Null
	Note "started $nights nights"
	$which = 'in a bar of its own'
	if ($bar -ne '') { $which = "carrying on bar $bar" }
	if ($freed) { $which += ' (ComfyUI stopped first, to free the GPU)' }
	return ToolText ("Started: $nights nights, $which. A night takes about 4 minutes (longer with Reading pauses on); the summary in logs\autoplay is written after every night." + $forgot)
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

# Stopping ComfyUI throws its queue away, so the pictures still listed as being made are taken off
# the list too (or queue_art_batch refuses until they're collected, and they never will be).
function StopArt {
	$listed = @(Pending).Count
	if (StopComfy) { return ToolText ('Stopped ComfyUI: the GPU is free for Ollama.' + (ForgetPending $listed)) }
	if (ComfyAnswers) { return ToolText "ComfyUI is answering but wasn't started from tools\comfyui_path.txt's folder: close its window on the PC." $true }
	return ToolText ("ComfyUI wasn't running." + (ForgetPending $listed))
}

# Empties art\raw\pending.json, and says so (nothing to say if it was empty).
function ForgetPending([int]$count) {
	SavePending @()
	if ($count -eq 0) { return '' }
	$what = 'pictures'
	if ($count -eq 1) { $what = 'picture' }
	Note "forgot $count $what still listed as being made"
	return " The $count $what still listed as being made went with its queue, so they're off the list (art\raw\pending.json): queue them again if they're still wanted."
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
	# (not piped, and each item handed back on its own: in Windows PowerShell 5.1 a one-item list came back
	# wrapped, and was saved a level deeper every time, so it was never fetched)
	try { $parsed = ConvertFrom-Json -InputObject (Get-Content -Path $file -Raw -Encoding UTF8); return @($parsed | ForEach-Object { $_ }) } catch { return @() }
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
	$fetched = 0
	foreach ($item in (Pending)) {
		if ($fetched -ge $CollectAtMost) { $still += $item; continue }
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
				if ([string]$item.reference -ne '') { $note.workflow = 'tools/art/klein_edit_api.json'; $note.reference = [string]$item.reference }
				ConvertTo-Json -InputObject $note | Set-Content -Path (Join-Path (RawFolder) "$base.json") -Encoding UTF8
				$lines += "art\raw\$base.png"
				$saved = $true
				$fetched++
			}
		}
		if (-not $saved) { $lines += "$($item.name) (seed $($item.seed)): finished without a picture (see ComfyUI's window)" }
	}
	SavePending $still
	if ($lines.Count -gt 12) { $lines = @("Fetched $($lines.Count) into art\raw\ (" + (($lines | Select-Object -First 3) -join ', ') + ', ...)') }
	if ($still.Count -gt 0) { $lines += "Still being made: $($still.Count) (collect_art fetches them)." }
	return $lines
}

# Queues pictures in ComfyUI (it works through its own queue, with or without us): $count of
# $prompt from $seed up (a batch skips any already in art\raw\). The pending items it queued.
function QueueArt([string]$prompt, [string]$name, [int]$seed, [int]$count, [int]$width, [int]$height, [string]$workflowFile, [bool]$skipMade = $false, [string]$reference = '') {
	$queued_items = @()
	$refName = ''
	if ($reference -ne '') {  # (redrawing a picture: it goes into ComfyUI's input folder, and the edit workflow's Load Image takes it)
		$workflowFile = Join-Path $PSScriptRoot 'art\klein_edit_api.json'
		$refName = "ktbt_$reference"
		Copy-Item -Path (Join-Path (RawFolder) $reference) -Destination (Join-Path (ComfyFolder) "ComfyUI\input\$refName") -Force
	}
	for ($k = 0; $k -lt $count; $k++) {
		if ($skipMade -and (Test-Path (Join-Path (RawFolder) "$($name)_$($seed + $k).png"))) { continue }  # (made already: a batch picks up where it left off)
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
			if ($type -eq 'LoadImage' -and $refName -ne '') { $inputs.image = $refName }
		}
		if (-not $prompted) { throw 'The workflow has no prompt box (a CLIPTextEncode node) to fill in.' }
		$body = ConvertTo-Json -InputObject ([ordered]@{ prompt = $workflow; client_id = 'ktbt-autoplay' }) -Depth 50 -Compress
		$queued = Invoke-RestMethod -Uri "$ComfyUrl/prompt" -Method Post -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json' -TimeoutSec 15
		$queued_items += [ordered]@{ prompt_id = [string]$queued.prompt_id; name = $name; seed = $seed + $k; prompt = $prompt; width = $width; height = $height; reference = $reference }
	}
	return $queued_items
}

# Why a reference picture won't do ('' if it will): a .png in art\raw\, and the edit workflow there.
function ReferenceProblem([string]$reference) {
	if ($reference -eq '') { return '' }
	if ($reference -notmatch '^[a-z0-9_-]{1,80}\.png$') { return 'reference: a .png in art\raw\ (lowercase, digits, - and _).' }
	if (-not (Test-Path (Join-Path (RawFolder) $reference))) { return "No art\raw\$($reference)." }
	if (-not (Test-Path (Join-Path $PSScriptRoot 'art\klein_edit_api.json'))) { return "No edit workflow: in ComfyUI, the Klein 4B image-edit template, Workflow > Export (API), saved as tools\art\klein_edit_api.json." }
	if ($null -eq (ComfyFolder)) { return "Can't find ComfyUI: put its folder on one line in tools\comfyui_path.txt." }
	return ''
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
	$reference = ''
	if ($null -ne $arguments.reference) { $reference = [string]$arguments.reference }
	$problem = ReferenceProblem $reference
	if ($problem -ne '') { return ToolText $problem $true }
	if ($null -ne (RunningBatch)) { return ToolText "An autoplay batch is running: Ollama has the GPU. Stop it first, or wait." $true }
	$problem = StartComfy
	if ($problem -ne '') { return ToolText $problem $true }
	$workflowFile = Join-Path $PSScriptRoot 'art\klein_api.json'
	if (-not (Test-Path $workflowFile)) { return ToolText "No workflow: in ComfyUI, Workflow > Export (API), saved as tools\art\klein_api.json." $true }
	$pending = @(@(Pending) + @(QueueArt $prompt $name $seed $count $width $height $workflowFile $false $reference))
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

# A batch from a list in art\raw\ (portraits.py --batch writes one): [{name, prompt, seed, count,
# width, height}], every picture queued in ComfyUI at once, which works through them on its own (no
# tokens while it runs; about 10 seconds a picture). Run again, it queues only what's missing.
function QueueArtBatch($arguments) {
	$file = 'portrait_batch.json'
	if ($null -ne $arguments -and [string]$arguments.file -ne '') { $file = [string]$arguments.file }
	if ($file -notmatch '^[a-z0-9_-]{1,60}\.json$') { return ToolText 'file: a .json list in art\raw\ (lowercase, digits, - and _).' $true }
	$path = Join-Path (RawFolder) $file
	if (-not (Test-Path $path)) { return ToolText "No art\raw\$($file): make it first (python3 tools/art/portraits.py --batch)." $true }
	$parsed = ConvertFrom-Json -InputObject (Get-Content -Path $path -Raw -Encoding UTF8)
	$jobs = @($parsed | ForEach-Object { $_ })  # (Windows PowerShell 5.1 hands a JSON list back as one item: this splits it)
	if ($null -ne (RunningBatch)) { return ToolText "An autoplay batch is running: Ollama has the GPU. Stop it first, or wait." $true }
	if (@(Pending).Count -gt 0) { return ToolText "Pictures are still being made: collect_art them first (or stop_art and start again)." $true }
	$problem = StartComfy
	if ($problem -ne '') { return ToolText $problem $true }
	$workflowFile = Join-Path $PSScriptRoot 'art\klein_api.json'
	if (-not (Test-Path $workflowFile)) { return ToolText "No workflow: in ComfyUI, Workflow > Export (API), saved as tools\art\klein_api.json." $true }
	$pending = @()
	foreach ($job in $jobs) {
		if ([string]$job.name -notmatch '^[a-z0-9_-]{1,60}$') { return ToolText "A job's name won't do: $($job.name)" $true }
		$reference = [string]$job.reference
		$problem = ReferenceProblem $reference
		if ($problem -ne '') { return ToolText "$($job.name): $problem" $true }
		$pending += @(QueueArt ([string]$job.prompt) ([string]$job.name) ([int]$job.seed) ([int]$job.count) ([int]$job.width) ([int]$job.height) $workflowFile $true $reference)
		SavePending $pending  # (as it goes, so a stop part-way still knows what's queued)
	}
	Note "queued a batch: $($pending.Count) pictures from $file"
	$minutes = [math]::Ceiling($pending.Count * 10 / 60)
	return ToolText "Queued $($pending.Count) pictures from art\raw\$file ($($jobs.Count) jobs; any already made skipped). ComfyUI works through them by itself: about $minutes minutes. collect_art fetches what's finished, $CollectAtMost at a time. Don't start autoplay meanwhile (it stops ComfyUI)."
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
			height = [ordered]@{ type = 'integer'; description = 'Pixels, 256 to 1536 in steps of 16 (default 1024).' }
			reference = [ordered]@{ type = 'string'; description = 'Optional: a picture in art\raw\ (e.g. portrait_w_20s_long_8000.png) to redraw, with the Klein edit workflow; the prompt says what to change (width and height then follow the picture).' } } } },
	[ordered]@{ name = 'queue_art_batch'; description = "Queue a whole list of KTBT art pictures in ComfyUI at once (a list in art\raw\, written by tools/art/portraits.py --batch): ComfyUI works through them by itself, with no tokens spent while it runs; collect_art fetches what's finished. Skips pictures already made, so running it again carries on. Not while an autoplay batch is running."
		inputSchema = [ordered]@{ type = 'object'; properties = [ordered]@{
			file = [ordered]@{ type = 'string'; description = 'The list in art\raw\ (default portrait_batch.json).' } } } },
	[ordered]@{ name = 'collect_art'; description = 'Fetch pictures generate_art or queue_art_batch was still making (up to 60 a call).'
		inputSchema = [ordered]@{ type = 'object'; properties = [ordered]@{} } },
	[ordered]@{ name = 'stop_art'; description = 'Stop ComfyUI, to give the GPU back (start_autoplay does this itself), and take any pictures still being made off the list (its queue goes with it).'
		inputSchema = [ordered]@{ type = 'object'; properties = [ordered]@{} } },
	[ordered]@{ name = 'import_assets'; description = "Import KTBT's new or changed art and fonts with Godot (headless, as the editor does when it opens), so the game and its tests use them without opening the editor. Waits until it's done (up to 3 minutes); start_autoplay does it first itself."
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
					'queue_art_batch' { QueueArtBatch $arguments }
					'collect_art' { CollectArt }
					'stop_art' { StopArt }
					'import_assets' {
						if ($null -ne (RunningBatch)) { ToolText 'A batch is running: import once it has finished (it imported as it started).' $true }
						else {
							$note = ImportAssets
							if ($null -eq $note) { ToolText "Can't find Godot: put the full path of its .exe on one line in tools\godot_path.txt." $true } else { ToolText $note }
						}
					}
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
