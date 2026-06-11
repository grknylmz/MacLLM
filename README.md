<div align="center">

# MacLLM

### *Run Apple Silicon LLMs with zero friction — right from your menu bar.*

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square&logo=apple)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/swift-5.9-F05138?style=flat-square&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![MLX](https://img.shields.io/badge/powered%20by-MLX-ff6b6b?style=flat-square)](https://github.com/ml-explore/mlx)

*A native macOS menu bar app for discovering, downloading, and serving MLX-format language models via an OpenAI-compatible API server.*

[Quick Start](#-quick-start) · [Installation](#-installation) · [Features](#-features-matrix) · [Developer Guide](#-developer-guide) · [Architecture](#-architecture)

</div>

---

## Why MacLLM?

> Running LLMs on Apple Silicon shouldn't require a terminal PhD.

- **Menu bar native** — lives in your status bar, always one click away
- **One-click downloads** — search & download models from HuggingFace directly
- **Built-in server** — launches an OpenAI-compatible API with zero config
- **Auto-detection** — automatically identifies quantization (4-bit, 8-bit, FP16) and parameter count
- **Fully offline-capable** — no cloud, no API keys, all local inference on your Mac

---

## Quick Start

### Prerequisites

| Requirement | Details |
|---|---|
| **Mac** | Apple Silicon (M1/M2/M3/M4) or later |
| **macOS** | 14.0 (Sonoma) or later |
| **Python** | System Python 3 at `/usr/bin/python3` |
| **Xcode** | 15.0+ with Swift 5.9 |
| **XcodeGen** | `brew install xcodegen` |

### Get Running in 60 Seconds

```bash
# 1. Clone the repo
git clone https://github.com/your-username/mac-llm.git
cd mac-llm

# 2. Generate the Xcode project
xcodegen generate

# 3. Open and run
open MacLLM.xcodeproj
```

Hit **Cmd+R** in Xcode — the brain icon appears in your menu bar. Click it, and the app will automatically set up a Python virtual environment and install `mlx-lm` on first launch.

### Your First Model

1. Click the brain icon in your menu bar
2. Switch to the **Download** tab
3. Search for a model (e.g., `Llama`, `Mistral`, `Phi`) or leave blank for popular picks
4. Click the download button
5. Once downloaded, the server starts automatically — visit `http://127.0.0.1:8080`

> **Tip:** Models from the [`mlx-community`](https://huggingface.co/mlx-community) org are pre-converted and work out of the box.

---

## Installation

### Option A: Build from Source (Recommended)

```bash
git clone https://github.com/your-username/mac-llm.git
cd mac-llm

# Generate Xcode project
xcodegen generate

# Build & run
open MacLLM.xcodeproj
```

### Option B: Download Pre-built App

> *Coming soon — check the [Releases](https://github.com/your-username/mac-llm/releases) page.*

### What Gets Installed Where?

| Path | Purpose |
|---|---|
| `~/.macllm/` | App data directory |
| `~/.macllm/venv/` | Isolated Python virtual environment |
| `~/.macllm/venv/bin/mlx_lm.server` | The MLX LM server binary |
| `~/.cache/huggingface/hub/` | Downloaded model weights (shared with `huggingface-cli`) |

---

## Features Matrix

### Core Capabilities

| Feature | Description | Status |
|---|---|---|
| **HuggingFace Search** | Search the entire HF Hub for MLX models | Done |
| **One-Click Download** | Download models with progress tracking | Done |
| **Model Management** | List, inspect, and delete installed models | Done |
| **API Server** | Launch OpenAI-compatible server (`mlx_lm.server`) | Done |
| **Model Switching** | Hot-swap models without restarting | Done |
| **Quick Open** | Open server URL in browser with one click | Done |
| **Server Restart** | Restart the server with one click | Done |

### Smart Detection

| Detection | How It Works | Status |
|---|---|---|
| **Quantization** | Auto-detects 4-bit, 8-bit, FP16, BF16 from model name | Done |
| **Parameter Count** | Parses 0.5B through 35B+ from model metadata | Done |
| **Disk Usage** | Calculates actual size on disk recursively | Done |
| **Install State** | Tracks which models are downloaded vs. available | Done |
| **Download Count** | Shows HF download stats for search results | Done |

### App Features

| Feature | Description | Status |
|---|---|---|
| **Menu Bar App** | Lives in macOS status bar, no Dock icon | Done |
| **Tab Interface** | Models / Download / Settings in a clean popover | Done |
| **Auto-Setup** | Creates venv + installs `mlx-lm` on first launch | Done |
| **Auto-Start** | Optionally auto-start last model on launch | Done |
| **Launch at Login** | macOS login item support | Done |
| **Configurable Port** | Change the server port in Settings | Done |
| **Reinstall Env** | One-click reinstall of Python environment | Done |
| **Live Server Logs** | Real-time server output in the UI | Done |

### API Compatibility

The built-in server uses `mlx_lm.server` which provides an **OpenAI-compatible API**:

```bash
# Chat completions
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "mlx-community/Mistral-7B-Instruct-v0.3-4bit", "messages": [{"role": "user", "content": "Hello!"}]}'

# Text completions
curl http://127.0.0.1:8080/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "mlx-community/Mistral-7B-Instruct-v0.3-4bit", "prompt": "Once upon a time"}'

# List models
curl http://127.0.0.1:8080/v1/models
```

---

## Architecture

```
MacLLM/
├── App
│   ├── MacLLMApp.swift           # SwiftUI app entry point
│   └── AppDelegate.swift         # Menu bar + popover lifecycle
│
├── Views
│   ├── PopoverView.swift          # Main tab container
│   ├── ServerStatusView.swift     # Server status bar with controls
│   ├── ModelListView.swift        # Installed models list
│   ├── DownloadView.swift         # HF search + download UI
│   └── SettingsView.swift         # Port, auto-start, env config
│
├── Managers
│   ├── ServerManager.swift        # Process lifecycle for mlx_lm.server
│   ├── ModelManager.swift         # Installed model discovery & deletion
│   ├── HuggingFaceClient.swift    # HF Hub API search client
│   └── PythonEnvManager.swift     # venv + pip setup automation
│
├── Models
│   ├── MLXModel.swift             # Local model representation
│   └── HFSearchResult.swift       # HuggingFace API response models
│
├── Utilities
│   ├── Constants.swift            # Paths, defaults, config values
│   └── ProcessRunner.swift        # Async process execution engine
│
└── Tests
    ├── Unit/                      # Unit tests per component
    └── Integration/               # Integration tests for managers
```

### Key Design Decisions

| Decision | Rationale |
|---|---|
| **SwiftUI + Observation** | Modern `@Observable` macro for reactive state |
| **Menu bar app (no Dock)** | Non-intrusive, always available, minimal screen space |
| **Separate Python venv** | Isolated env at `~/.macllm/venv/` — no system pollution |
| **HF cache reuse** | Uses standard `~/.cache/huggingface/hub/` for model storage |
| **Process-based server** | Runs `mlx_lm.server` as a child `Process` for clean lifecycle control |

---

## Developer Guide

### Project Setup

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`:

```bash
# Install XcodeGen
brew install xcodegen

# Regenerate project (run after adding/removing files)
xcodegen generate
```

### Building & Running

```bash
# Open in Xcode
open MacLLM.xcodeproj

# Or build from CLI
xcodebuild -project MacLLM.xcodeproj \
  -scheme MacLLM \
  -configuration Debug build
```

### Running Tests

```bash
# Run all tests
xcodebuild test -project MacLLM.xcodeproj \
  -scheme MacLLMTests \
  -destination 'platform=macOS'

# Run only unit tests
xcodebuild test -project MacLLM.xcodeproj \
  -scheme MacLLMTests \
  -only-testing:MacLLMTests/UnitTests
```

### Test Structure

```
MacLLMTests/
├── Unit/
│   ├── HuggingFaceClientTests.swift   # HF API client tests
│   ├── MLXModelTests.swift            # Model parsing & detection
│   ├── ServerManagerTests.swift       # Server lifecycle tests
│   ├── ProcessRunnerTests.swift       # Process execution tests
│   ├── ProcessResultTests.swift       # Result parsing tests
│   └── ConstantsTests.swift           # Path resolution tests
│
└── Integration/
    ├── ModelManagerTests.swift         # Full model management flow
    ├── ServerManagerIntegrationTests.swift  # Real server start/stop
    └── PythonEnvManagerTests.swift     # Full env setup flow
```

### Adding a New View

1. Create `MacLLM/Views/MyNewView.swift`
2. Use `@Observable` classes from `Managers/` for state
3. Run `xcodegen generate` to update the project
4. Integrate into `PopoverView.swift`

### Adding a New Manager

1. Create `MacLLM/Managers/MyManager.swift`
2. Annotate with `@Observable @MainActor`
3. Instantiate in `AppDelegate.swift`
4. Pass through `PopoverView` to the views that need it
5. Add corresponding tests in `MacLLMTests/`

### Adding Dependencies

Edit `project.yml` to add frameworks or packages, then regenerate:

```bash
xcodegen generate
```

### Code Style

| Convention | Standard |
|---|---|
| Language | Swift 5.9 |
| Architecture | MVVM (Observable) |
| UI Framework | SwiftUI |
| Concurrency | Swift async/await + `@MainActor` |
| Process Management | `Foundation.Process` via `ProcessRunner` |
| Deployment Target | macOS 14.0 |

---

## Roadmap

- [ ] Chat UI — built-in conversation interface
- [ ] Drag & drop model import
- [ ] System resource monitoring (RAM, GPU)
- [ ] Model versioning & update detection
- [ ] Multi-language support
- [ ] Shortcuts / Automator integration
- [ ] Homebrew Cask distribution

---

## Contributing

Contributions are welcome! Here's how:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to the branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

### Guidelines

- Follow existing Swift code style (no unnecessary comments)
- Add tests for new functionality
- Run `xcodegen generate` if you add/remove files
- Keep the menu bar footprint minimal

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Built for the Apple Silicon community**

*Powered by [MLX](https://github.com/ml-explore/mlx) · [mlx-lm](https://github.com/ml-explore/mlx-lm) · [HuggingFace](https://huggingface.co)*

</div>
