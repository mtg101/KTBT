# KTBT: Toolchain Setup

How to set up the tools KTBT needs on a Windows PC. Do this once, before any code is written.

| Tool | What it's for | Version used |
|---|---|---|
| Godot | Game engine and editor (scenes plus GDScript code) | 4.7.x, **standard** build |
| Ollama | Runs the local AI model and serves it over HTTP | Latest |
| An LLM | Invents the owner and customers and writes their dialogue | Llama 3.1 8B to start |

**Reference machine:** Windows, NVIDIA RTX 3080. Most 3080s have 10GB of video memory (some have 12GB), so 7–9B models in compressed ("quantised") form are the sweet spot.

---

## 1. Godot

1. Go to **https://godotengine.org/download/windows**.
2. Download **Godot Engine (standard)** for x86_64. Do **not** pick the .NET version. That one is for C#, and we're using GDScript.
3. It's a zip file, not an installer. Extract it somewhere permanent, e.g. `C:\Tools\Godot\`.
4. Optional: right-click `Godot_v4.x-stable_win64.exe` and choose **Send to → Desktop (create shortcut)**.
   - Ignore the `_console.exe` file. It's the same editor with a log window attached, which is handy later for debugging.
5. Run it. You'll see the **Project Manager**. That's enough for now.

**Opening KTBT later:** once the project files exist, click **Import** in the Project Manager and pick `project.godot` in the project's folder (wherever you cloned it). After that, KTBT appears in your project list.

---

## 2. Ollama

### Install
1. Check your NVIDIA driver is reasonably current (version 551.61 or newer). Use the NVIDIA App or GeForce Experience to update if needed.
2. Go to **https://ollama.com/download**. It offers two ways to install. Either is fine:
   - **The PowerShell one-liner** shown on the page: `irm https://ollama.com/install.ps1 | iex`. `irm` (Invoke-RestMethod) downloads Ollama's install script and `iex` (Invoke-Expression) runs it. Paste it into a normal (non-admin) PowerShell window. Only use this command when it comes straight from ollama.com, since it runs whatever the URL serves.
   - **The installer**: download `OllamaSetup.exe` (look for a "Download for Windows" button or link) and double-click it.
3. Either way: You don't need admin rights. Ollama then runs in the background (look for the llama icon in the system tray) and starts with Windows.

### Check it's running
Open **PowerShell** and run:

```powershell
ollama --version
```

You should see a version number. If the command isn't found, close and reopen PowerShell.

### Where models are stored (optional)
Models download to `C:\Users\<you>\.ollama\models` by default, and each one is several GB. To keep them on another drive:
1. Search Windows for **"Edit environment variables for your account"**.
2. Add a new variable named `OLLAMA_MODELS`, with a folder such as `D:\OllamaModels` as its value.
3. Quit Ollama from the tray icon and start it again.

---

## 3. The model

### Download it
```powershell
ollama pull llama3.1:8b
```
It's roughly a 5GB download.

### Talk to it
```powershell
ollama run llama3.1:8b
```
Always give `ollama run` the model name. Running it on its own just complains about a missing argument. If the model isn't downloaded yet, `run` pulls it first.
Try: *"Invent a customer who walks into a Seoul pojangmacha at 2am on a rainy Tuesday. Two sentences."*
Type `/bye` to exit.

### Other models worth trying
We'll compare these with the same customer prompt once the pipeline works, and keep the one that writes the best characters:

```powershell
ollama pull gemma2:9b
ollama pull qwen2.5:7b
```

Check what's installed with `ollama list`, and remove a model with `ollama rm <name>`.

> Model names change over time. If a pull fails, check **https://ollama.com/search** for current names. Anything around 7–9B parameters fits the 3080.

---

## 4. Check the API (the way Godot will talk to it)

Godot won't use the terminal. It sends HTTP requests to Ollama at **`http://localhost:11434`**. To test that route, paste this into PowerShell:

```powershell
$body = @{
  model    = "llama3.1:8b"
  messages = @(@{ role = "user"; content = "Invent a pojangmacha customer. Reply as JSON with name, age, job, mood." })
  format   = "json"
  stream   = $false
} | ConvertTo-Json -Depth 5

(Invoke-RestMethod -Uri "http://localhost:11434/api/chat" -Method Post -Body $body -ContentType "application/json").message.content
```

You should get back a small JSON object describing a customer. If you do, the whole toolchain works. ✅

---

## 5. Sanity checks and troubleshooting

- **Is the GPU being used?** While a model is answering, run `ollama ps` in another PowerShell window. The PROCESSOR column should say **100% GPU**. If it shows CPU, the model is too big for your video memory, or the driver needs updating.
- **Video memory headroom:** run `nvidia-smi` to see how much is in use. Close GPU-hungry apps (games, Chrome with lots of tabs) if a model won't fit.
- **First reply is slow:** normal, and confirmed on the reference machine. The first request loads the model from disk into GPU memory, which takes several seconds. After that, replies are near instant. Ollama unloads the model after about 5 minutes idle, so the first message after a break is slow again. (The game will keep the model loaded while it's running.)
- **Measuring speed:** run `ollama run llama3.1:8b --verbose`. After each reply it prints a stats block. **eval rate** is how fast it writes (expect ~60–100 tokens/s on a 3080), and **load duration** shows time spent loading the model. Judge by the second or third reply, not the first.
- **Task Manager says the GPU is idle:** its GPU graph shows the "3D" engine by default, which games use. Ollama uses CUDA, which doesn't show there. Click the dropdown above one of the small GPU graphs and switch it to **Cuda** or **Compute_0** to see the real load. Dedicated GPU memory is a better quick check: it should go up by roughly 5–6GB when the model is loaded.
- **"Could not connect" errors:** make sure Ollama is running (tray icon), or start it by running `ollama serve` in a terminal.
- **Port already in use:** something else has port 11434. Restarting the PC usually fixes it.
- **"Identifier not declared" or tests going missing after a `project.godot` change:** Godot only reads project settings (autoloads, the main scene, the window size) when the project loads. After editing `project.godot` outside the editor, use **Project → Reload Current Project**.

---

## 5a. Machines without a suitable GPU

The reference setup assumes an NVIDIA GPU with about 10GB+ of video memory. On a machine without one (e.g. a laptop with integrated graphics) there are three ways to work. All three are chosen in the AI settings file (section 5b).

### Option 1: canned AI (offline mode)
Set `backend="canned"` in the AI settings. No AI needed at all. The game answers from a small library of pre-written characters and lines, instantly. Good for working on anything except the writing: UI, saving, the night clock, seats, art. It's also what the automated tests use. With the default `backend="auto"`, the game also switches to it by itself if Ollama can't be reached, and shows an **OFFLINE MODE** badge.

### Option 2: Ollama on the CPU with a small model
Ollama runs without a GPU, using the processor instead. It's much slower, so use a small model:

```powershell
ollama pull llama3.2:3b
```

Then set `model="llama3.2:3b"` in the AI settings. Expect replies to take several seconds and the writing to be weaker than the 8B model. While it's answering, `ollama ps` will show **100% CPU**, which is expected here.

### Option 3: use the desktop's Ollama over your home network
The laptop's game talks to Ollama running on the desktop (which must be on). Full-quality AI, at home only.

**On the desktop (once):**
1. Search Windows for **"Edit environment variables for your account"** and add a variable named `OLLAMA_HOST` with the value `0.0.0.0:11434`. This makes Ollama accept connections from other machines, not just the desktop itself.
2. Quit Ollama from the tray icon and start it again.
3. If Windows Firewall asks whether to allow Ollama on **private networks**, allow it. (If it doesn't ask and the laptop can't connect, add an inbound rule allowing TCP port 11434 on private networks.)
4. Find the desktop's address: run `ipconfig` and note the **IPv4 Address** (e.g. `192.168.1.20`).

**On the laptop, check it can reach the desktop:**
```powershell
Invoke-RestMethod http://192.168.1.20:11434/api/tags
```
It should list the desktop's models. Then set `server="http://192.168.1.20:11434"` in the AI settings.

> Only do this on a home network you trust: anyone on the same network can use the desktop's Ollama while it's set up this way. Remove the `OLLAMA_HOST` variable to switch it off. The desktop's address can also change after a router restart; if the laptop stops connecting, check `ipconfig` again.

---

## 5b. AI settings: choosing which AI the game uses

Each machine has its own small settings file that says which AI to use, so the desktop (with a big GPU) and the laptop (without one) can share the project. It's created with the defaults the first time the game or the tests run.

**Where it is:** in Godot's user data folder for the project, not in the project folder. The easiest way there is **Project → Open User Data Folder** in Godot. Or paste `%APPDATA%\Godot\app_userdata\KTBT` into Explorer's address bar. The file is `ai_settings.cfg`; open it in any text editor.

**What's in it (the defaults):**
```ini
[ai]
backend="auto"
server="http://127.0.0.1:11434"
model="llama3.1:8b"
```

**`backend`: which AI answers:**

| Setting | What it does | When to use it |
|---|---|---|
| `auto` (default) | Uses Ollama. At startup it checks Ollama answers within 3 seconds; if not, or if Ollama later fails to answer, it switches to offline mode for the rest of the session and shows the **OFFLINE MODE** badge. | Normal use on any machine: it works whether Ollama is running or not. |
| `ollama` | Always uses Ollama, never falls back. If Ollama isn't available, the game says so (e.g. "Couldn't invent the owner"). | When you want to be sure you're seeing real AI output: tuning prompts, comparing models. |
| `canned` | Never contacts Ollama. Uses the pre-written characters and lines straight away (offline mode), with the badge showing from the start. | The laptop, or when working on anything other than the writing (UI, flow, timing) and you want instant visits. |

**`server`:** where Ollama is. `http://127.0.0.1:11434` means this machine; use another PC's address to borrow its Ollama (option 3 in section 5a).

**`model`:** which Ollama model to use, e.g. `llama3.1:8b`, or `llama3.2:3b` on a machine without a suitable GPU. It must already be pulled (`ollama list` shows what you have).

**Notes:**
- Keep the quotes around values (`backend="canned"`). A misspelt backend shows a warning in Godot's Output panel and falls back to `auto`.
- Changes take effect next time you press F5.
- The file stays out of the repo on purpose, so pulling changes on one machine never overwrites another machine's choice.
- The **OFFLINE MODE** badge in the top bar is the giveaway that you're seeing canned characters; hover over it to see why the game is offline.

---

## 6. Optional but recommended

### Git
**Git** (https://git-scm.com/download/win) for version control, so we can roll back when an experiment goes wrong. The project already includes a `.gitignore` (which keeps Godot's `.godot/` cache folder out) and a `.gitattributes`.

### VS Code
**VS Code** is handy for reading scripts, previewing the `.md` docs and running commands. It isn't required, since Godot has its own script editor.

**GDScript highlighting:** VS Code doesn't understand `.gd` files out of the box.
1. Press `Ctrl+Shift+X` to open Extensions.
2. Search for **godot-tools** (publisher *Godot Engine*, ID `geequlim.godot-tools`) and click **Install**.

That highlights `.gd`, `.tscn` and `project.godot` files straight away.

**Autocomplete, hover docs and error underlining (optional):** keep the Godot editor open with the KTBT project loaded, and the extension connects to it automatically; the status bar shows when it's connected. Or, without the editor: turn on **Godot Tools › LSP: Headless** (`godotTools.lsp.headless`), and the extension starts a hidden Godot of its own just for this. On the desktop that's turned on, and since 17 November 2026 it often fails: "Couldn't connect to the GDScript language server at 127.0.0.1:<a different port each time>" pops up, usually after VS Code starts. It's harmless (the game, tests and autoplay don't use it): click **Ignore**, or turn headless off to rely on the open editor. Why it fails is in PLAN (Lower priority).

**Playing from VS Code (F5):** the extension can start the game itself, with its debugger (errors and `print()` in the Debug Console), so the Godot editor needn't be open to play. Set **Godot Tools › Editor Path: Godot4** in VS Code's settings to your Godot `.exe`, then add `.vscode/launch.json` with one configuration: `"type": "godot"`, `"request": "launch"`, `"project": "${workspaceFolder}"`, `"port": 6010` (not 6007, which the editor uses when it's open). F5, or **Run → Start Debugging**, plays the game. The `.vscode` folder isn't in git (it holds local paths), so each machine sets this up once.

**Autoplay from VS Code:** two more entries, in the same local `.vscode` files: a task, **Autoplay nights** (`tasks.json`: `"command": "${config:godotTools.editorPath.godot4}"`, `"args": ["--path", "${workspaceFolder}", "--", "--autoplay=${input:nights}"]`, with a `promptString` input asking how many, default 10), run from **Ctrl+Shift+P → Tasks: Run Task**; and a launch configuration, **Autoplay 10 nights** (`launch.json`: the same as Play KTBT, with `"additional_options": "-- --autoplay=10"`), for a batch with the debugger.

**Opening scripts from Godot in VS Code (optional):** in Godot, go to **Editor → Editor Settings → Text Editor → External**, tick **Use External Editor**, and set **Exec Path** to VS Code's `Code.exe`.

**Built-in terminal:** **Terminal → New Terminal** opens PowerShell in the project folder. On a UK keyboard, the `` Ctrl+` `` shortcut shown in the menus often doesn't work. Press `Ctrl+K Ctrl+S`, search for **View: Toggle Terminal**, and record a shortcut that does.

**Markdown preview:** `Ctrl+Shift+V` opens it in a tab, and `Ctrl+K V` opens it side by side.

---

## 6a. Autoplay from your phone (optional)

A batch of autoplay nights (README, "Autoplay") can be started by double-clicking `tools\autoplay.bat`. To let Claude start one when you're not at the PC (from the Claude app on your phone, in a chat linked to this PC), add the project's small helper, `tools\autoplay_mcp.ps1`, as a local MCP server in the Claude desktop app. It can do three things only: start a batch, say how one's going (and whether Ollama's answering), and stop one. No other programs, no general shell, and Ollama stays on `localhost`.

1. Put Godot's path in `tools\godot_path.txt` (one line, the full path of its `.exe`), if it isn't there already.
2. **Quit the Claude desktop app completely** (right-click its tray icon, **Quit**: closing the window isn't enough). It rewrites its config file while it runs, so an edit made with it open can be lost.
3. Open the app's config file, `claude_desktop_config.json`. Where it is depends on how the app was installed (see "Why it's fiddly" below). On the Microsoft Store version it's in `%LOCALAPPDATA%\Claude-Data\claude_<letters>\`, next to the app's own `config.json`; on the other installer it's usually `%APPDATA%\Claude\`. The app makes this file itself, so it's normally there already, full of its own settings: don't replace it, add to it.
4. Add the helper as a top-level `mcpServers` section, with your own path to the KTBT folder and every `\` doubled (if there's already an `mcpServers` section, add the `"ktbt-autoplay": {...}` entry inside it):
   ```json
   {
     "mcpServers": {
       "ktbt-autoplay": {
         "command": "powershell.exe",
         "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:\\path\\to\\KTBT\\tools\\autoplay_mcp.ps1"]
       }
     },
     ...the app's own settings, unchanged...
   }
   ```
   Keep it valid JSON (a comma after the `mcpServers` section), saved as UTF-8.
5. Start the app again. To check it took, ask Claude in a chat linked to the PC whether it can see the `ktbt-autoplay` tools (it can see which local servers the app started, and whether they're running).
6. Leave the PC on and awake (the app's **Settings → Desktop app → Keep computer awake**), with Ollama and the Claude desktop app running. From your phone, in a chat linked to the PC: "start 10 autoplay nights", "how's the batch going?", "stop the batch". The helper knows a batch is running from `logs\autoplay\running.json`, which the game keeps while one is (after a change to the helper, restart the app: it only loads it at the start). Claude reads how it went from the logs (step 7 below).
7. For Claude to read the results, the chat needs the KTBT folder connected (the desktop app's **Add folder**), and Godot's user folder for `godot.log` and the saves (`%APPDATA%\Godot\app_userdata\KTBT`).

### Why it's fiddly

Set up on 17 November 2026, after a long evening. What got in the way, for next time:

- **Claude's shell can't start Windows programs.** In a chat linked to the PC, Claude's "shell on the PC" is a small Linux virtual machine the desktop app runs, with your connected folders shared into it. There's no `cmd.exe` or PowerShell in it, and no Godot, so it can't start `Godot.exe`; and its network goes through an allowlist, so it can't reach Ollama on `localhost` either. It's for reading and changing files (the logs, the code), not running the game.
- **Only the desktop app can start things on Windows.** Claude can also click and type on the screen (computer use), but that takes over the PC and needs approving app by app. The other way is a local MCP server: a program the app itself starts, whose tools Claude can call. That's what the helper is, and why it only does three things.
- **There's no Developer settings page.** Older guides (and an earlier version of this section) say **Settings → Developer → Edit Config**; this version of the app has no such page, so the file has to be found and edited by hand.
- **The Store version keeps its files in odd places.** Windows gives a Store app a private copy of `%APPDATA%`: the app sees `%APPDATA%\Claude`, but in Explorer it isn't there (it's really under `%LOCALAPPDATA%\Packages\Claude_<letters>\LocalCache\Roaming\Claude`). And the app has since moved its data out of that too, into `%LOCALAPPDATA%\Claude-Data\claude_<letters>\`, leaving only a marker file (`.user-data-left...`) behind. A config file put in either of the old places is quietly ignored. The app's own log, `%LOCALAPPDATA%\Claude\logs\main.log`, says where its data is (search it for `config.json`), and says `no stdio servers connected` when it found no helper.
- **Claude can't look in the app's own folders.** It's not allowed to read the desktop app's data or logs, even when asked, so finding the config file and reading the log are jobs for you.
- **An extension isn't the same thing.** A `.mcpb` "extension" installed through the app is a different route; it needs its settings filled in before it's switched on. The helper doesn't use one.

---

## 7. Testing: GdUnit4

KTBT's automated tests use **GdUnit4**, a free Godot add-on. How we use it is in [TESTS.md](TESTS.md). This section covers installing and running it.

### Pick the right version
GdUnit4 releases are tied to Godot versions. The project now lives at **https://github.com/godot-gdunit-labs/gdUnit4** (older links to `MikeSchulze/gdUnit4` point to the same project). Its compatibility table, checked 13 November 2026:

| GdUnit4 | Supports Godot |
|---|---|
| v7.0.0 (in development, not released) | 4.7, 4.7.1, 4.8 dev |
| **v6.2.x** | 4.5 to 4.5.2, 4.6 to 4.6.3, 4.7, 4.7.1 |
| v6.1.x | 4.5 to 4.5.2, 4.6 to 4.6.3 |
| v6.0.x | 4.5 to 4.5.2 |
| v5.x | 4.3, 4.4, 4.4.1 |
| Older | Godot 4.0 to 4.3 |

**Latest release:** v6.2.2 (7 October 2026). Recent releases: v6.2.0 (July), v6.2.1 (August), v6.2.2 (October).

**What we use:** **v6.2.0**, installed from the Godot Asset Store, which (as of 13 November 2026) lags GitHub by two bug-fix releases. That's the same v6.2 line, with the same Godot support. We're on Godot **4.7.2**, which isn't in the table yet: it's a patch release just after 4.7.1, and patch releases rarely break plugins. Confirmed 13 November 2026: all 61 tests run and pass on 4.7.2. If we hit a bug fixed in v6.2.1 or v6.2.2, or v6.2.0 doesn't work with 4.7.2, install the newer release by hand from the releases page (https://github.com/godot-gdunit-labs/gdUnit4/releases).

**When we upgrade Godot,** check this table first, and upgrade GdUnit4 to a release that lists the new Godot version.

### Install
Godot 4.7 replaced the old **AssetLib** tab with the official **Godot Asset Store**, so older guides that mention AssetLib are out of date.

**From the Asset Store (what we did):**
1. In Godot, open the **Asset Store** tab at the top of the editor. If it won't load, check **Editor → Editor Settings → Network** and set the network mode to online.
2. Search for **GdUnit4** and pick **GdUnit4 - Unit Testing Framework**. Check the version shown is in the v6.2 line (see the table above).
3. Install it. It goes into `addons/gdUnit4/`.
4. Go to **Project → Project Settings → Plugins** and tick **Enabled** next to GdUnit4. Godot records this in `project.godot`.
5. Restart the editor if asked. A **GdUnit** tab appears in the editor.

**By hand from GitHub (for a newer release than the store has):**
1. On the releases page (https://github.com/godot-gdunit-labs/gdUnit4/releases), download the **Source code (zip)** for the release you want.
2. Unzip it and copy its `addons/gdUnit4` folder into the project as `addons/gdUnit4/`, replacing any older copy.
3. Enable the plugin as in step 4 above.

The `addons/gdUnit4/` folder is committed to the repo, so anyone cloning the project gets the same version.

### Run tests in the editor
- Open the **GdUnit** panel and click **Run All**, or right-click the `tests/` folder in the FileSystem dock and choose **Run Tests**.
- Results show in the panel, with failures linking to the line that failed.

### Run tests from the command line
Useful for a quick check from VS Code's terminal, and for running tests automatically on GitHub.

1. Tell GdUnit4 where Godot is (once). Use the **console** build, which prints output to the terminal:
   ```powershell
   setx GODOT_BIN "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
   ```
   Then open a new terminal so it picks up the setting.
2. From the project folder:
   ```powershell
   .\addons\gdUnit4\runtest.cmd -a res://tests -c
   ```
   `-a` says which tests to run, and `-c` keeps going after a failure so you see them all.
3. Reports are written to `reports/` (an HTML page and a JUnit XML file). That folder is in `.gitignore`.

If the colours in the terminal look like garbage, see the GdUnit4 docs on enabling ANSI colours in Windows consoles.

### On GitHub (optional, later)
GdUnit4 has a ready-made GitHub Action (`gdunit4-action`) that runs the tests on every push. We'll set it up once there's a meaningful test suite.

---

## Setup checklist

✅ All verified on the reference machine (Windows, RTX 3080 12GB) on 12 November 2026.

- [x] Godot 4.7.x (standard) extracted and opens to the Project Manager
- [x] Ollama installed, and `ollama --version` works
- [x] Model downloaded: `ollama pull llama3.1:8b` (or let the next step download it)
- [x] `ollama run llama3.1:8b` gives sensible replies. `ollama run` needs the model name; on its own it just errors. Type `/bye` to exit.
- [x] `ollama list` shows `llama3.1:8b`
- [x] The PowerShell API test returns JSON
- [x] `ollama ps` shows 100% GPU while a reply is being generated

Added later:

- [x] GdUnit4 installed and enabled, and the test suite runs and passes (13 November 2026: v6.2.0 on Godot 4.7.2, 61 tests)
