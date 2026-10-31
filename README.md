# RepoSéance 👻

> **Summon the ghost in the machine.**  
> A local-first, privacy-respecting AI software archaeology workbench that reconstructs the purpose, architecture, and development history of unfamiliar or abandoned Git repositories — powered by Google's Gemma model running 100% locally on your machine with verifiable, source-grounded evidence citations.

Built for **DEV Hacktoberfest 2026 Week 4: "Ghost in the Machine"**.

---

## ⚡ Highlights & Key Features

- 🔒 **100% Local & Offline**: Operates entirely on your machine via direct loopback HTTP (`127.0.0.1:11434`) to local Ollama. Zero outbound telemetry, zero cloud API keys, zero cloud egress.
- 🛡️ **Zero-Execution Sandbox**: Inspects repository text and Git metadata deterministically. **Never** executes arbitrary build scripts, test runners, npm scripts, or hooks found inside untrusted target repositories.
- 📜 **Evidence-Grounded Citations**: Every claim in the generated autopsy and Q&A references concrete evidence items (e.g. `[E001]`). Claims cannot hallucinate uninspected files or confabulate non-existent commits.
- 🧠 **Gemma 4:e2b Engine**: Leverages Google's Gemma model locally on standard laptop CPU (no discrete GPU required).
- 💬 **Ask the Ghost (Interactive Q&A)**: Pure Dart deterministic lexical retrieval engine combined with bounded prompt injection fencing (`<evidence_snippet>`). Honest refusal (`not_found: true`) when developer intent or motive is absent from repository records.
- 📑 **Sanitized Markdown Export**: Export forensic autopsy reports with automatic Windows user profile scrubbing (`<user-home>/`), API credential masking, and Markdown pipe escaping.
- 🧪 **Rigorously Tested**: 146 unit, widget, integration, and adversarial red-team tests passing with 100% green status.

---

## 🏛️ System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│               RepoSéance Desktop Workbench (Flutter Windows)          │
│                                                                        │
│   ┌────────────────────┐   ┌───────────────────┐   ┌───────────────┐   │
│   │ Safe Git Service   │   │ Bounded Scanner   │   │ State Store   │   │
│   │ (runInShell: false)│   │ (5k files, 2MB max│   │ (Provider)    │   │
│   └─────────┬──────────┘   └─────────┬─────────┘   └───────┬───────┘   │
│             │                        │                     │           │
│             └────────────────┬───────┴─────────────────────┘           │
│                              ▼                                         │
│                Immutable Evidence Snapshot                             │
│         [ FileEvidence (SHA-256) | CommitEvidence ]                   │
│                              │                                         │
│              ┌───────────────┴───────────────┐                         │
│              ▼                               ▼                         │
│   Deterministic Lexical Q&A        Structured Prompt Assembly          │
│   (Zero-vector-DB, <1ms filter)    (XML Delimiter Fencing)             │
│              │                               │                         │
└──────────────┼───────────────────────────────┼─────────────────────────┘
               │ Loopback HTTP (127.0.0.1:11434)│
               ▼                               ▼
┌────────────────────────────────────────────────────────────────────────┐
│             Local Ollama Daemon (v0.40.13+) / Gemma 4:e2b              │
│                (CPU GGUF Inference, Temperature 0.1)                  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quickstart & Prerequisites

RepoSéance requires an external background Ollama daemon hosting the `gemma4:e2b` model.

### 1. Prerequisites (Ollama & Model)

Install and start Ollama, then pull the Gemma model:

```powershell
# Install Ollama on Windows (via winget)
winget install Ollama.Ollama

# Start Ollama service (if not running in system tray)
ollama serve

# Pull the Gemma model (approx 4.6 GB download)
ollama pull gemma4:e2b

# Verify Git is installed
git --version
```

### 2. Run Precompiled Windows Package

1. Download and extract `reposeance-v1.0.0-windows-x64.zip`.
2. Ensure Ollama is running.
3. Double-click `reposeance.exe`.
4. The Readiness Shell will verify your Ollama connection and confirm the `gemma4:e2b` model is loaded.
5. Select any local Git repository folder to commence the autopsy!

### 3. Build & Run from Source

```powershell
# Clone the repository
git clone https://github.com/Joyy-dev/reposeance.git
cd reposeance

# Fetch dependencies
flutter pub get

# Run on Windows desktop in debug mode
flutter run -d windows

# Or build the standalone release runner
flutter build windows --release
```

---

## 📊 Measured Host Hardware Profile

Benchmarked on physical host hardware:
- **Host Device**: HP EliteBook 830 G7
- **Processor**: Intel Core CPU @ 1.80GHz – 2.30GHz
- **RAM**: 16 GB DDR4
- **OS**: Windows 11 Pro 64-bit (Build 26300)
- **Model Configuration**: `gemma4:e2b` (4.6 GB GGUF), CPU execution, `"think": false`, Temperature 0.1

| Operation | Metric | Measured Value |
|---|---|---|
| **Prompt Evaluation Speed** | Token Throughput | ~40.8 tokens/sec |
| **Token Generation Speed** | Output Throughput | ~9.65 tokens/sec |
| **Full Autopsy Duration (Cold Start)** | First Run (Disk → RAM) | ~108 seconds |
| **Full Autopsy Duration (Warm)** | Subsequent Runs | ~100 seconds |
| **Ask the Ghost Q&A Latency** | Warm Retrieval + Answer | ~29.4 seconds |
| **Lexical Retrieval Engine** | Dart Keyword Filter | < 1 millisecond (Zero DB overhead) |

*Note: Because RepoSéance runs 100% locally on standard consumer CPU without an external GPU or remote cloud cluster, generating a full 8-section structured autopsy takes ~100 seconds. All test runs and demo videos disclose this processing duration transparently.*

---

## 🛡️ Security, Privacy & Boundaries

1. **Untrusted Code Isolation**: RepoSéance is a static read-only forensic tool. It does not invoke `npm install`, `dart pub get`, `cmake`, `make`, `python`, or any scripts discovered within target repositories.
2. **Path Sanitization**: Directory traversal attacks (`../../`) and Windows reparse points are strictly rejected. Paths outside the inspected root are unreachable.
3. **Sensitive Credential Exclusions**: The bounded scanner automatically excludes `.env`, `prod.env`, `.pem`, `.key`, `id_rsa`, `.git/`, and binary file types (null-byte detection).
4. **Loopback Enforcement**: Network requests are hardcoded to `http://127.0.0.1:11434`. Redirects to non-loopback domains are rejected by client validation.
5. **Privacy Scrubbing in Reports**: Exported Markdown files automatically sanitize the local user's home directory (`C:\Users\<username>\...` → `<user-home>/...`) and escape Markdown table formatting characters (`\|`).

---

## 🧪 Verification & Test Suite

The RepoSéance codebase is backed by a 146-test automated regression and adversarial suite:

```powershell
# Code style and formatting check
dart format --output=none --set-exit-if-changed lib test

# Static analysis
flutter analyze

# Complete test suite (unit + widget)
flutter test test/unit/ test/widget/

# End-to-end integration tests (requires live Ollama daemon)
flutter test test/integration/local_gemma_autopsy_test.dart
flutter test test/integration/local_gemma_ghost_qa_test.dart
```

### Adversarial Red-Team Test Coverage
- **Autopsy Service (`adversarial_autopsy_test.dart`)**: Unsupplied evidence IDs (`E999`), additional JSON schema properties, array length DoS, malformed JSON repair recovery, and cancellation safety.
- **Q&A Assistant (`adversarial_ghost_qa_test.dart`)**: Prompt injection fencing, delimiter collisions, motive confabulation prevention, and lexical retrieval short-circuiting.
- **Scanner (`adversarial_scanner_test.dart`)**: Disguised binaries, secret file exclusion, traversal boundaries, and max depth limits.
- **Export (`adversarial_export_test.dart`)**: User profile redaction, token scrubbing, and Markdown table pipe escaping.

---

## 📄 Provenance & Frozen Release

- **Hackathon Challenge**: DEV Hacktoberfest 2026 Week 4 — "Ghost in the Machine"
- **Author**: Joyce Ava ([@joyy-dev](https://github.com/Joyy-dev))
- **Frozen Release Commit**: `042ccfae938a20966f7f321d9dc2f1d3963d0aee`
- **License**: MIT License (see [LICENSE](LICENSE) for details)
