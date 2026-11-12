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

**Opening KTBT later:** once the project files exist, click **Import** in the Project Manager and pick `C:\Code\Claude\KTBT\project.godot`. After that, KTBT appears in your project list.

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

---

## 6. Optional but recommended

- **Git** (https://git-scm.com/download/win), for version control so we can roll back when an experiment goes wrong. Godot can generate a suitable `.gitignore` for us.
- **VS Code** with the **godot-tools** extension, if you'd rather read and edit scripts outside Godot's built-in editor. Not required.

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
