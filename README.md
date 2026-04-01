# kc - Keychain CLI Tool

A lightweight Swift CLI tool for securely storing and retrieving API keys and secrets in the macOS Keychain with iCloud sync support.

## Features

- Store sensitive keys like API tokens in macOS Keychain
- Signed install with `keychain-access-groups` entitlement for synchronizable items
- Automatic iCloud Keychain sync across your Apple devices
- Simple command-line interface
- Secret input via `--stdin` or secure `--prompt`
- Local-only or sync-only write modes
- Migration command for existing local-only keys

## Installation

```bash
make install
```

This builds a signed macOS app bundle via Xcode (with automatic provisioning updates), installs it to:

- App bundle: `~/.local/share/kc/kc.app`
- CLI wrapper: `~/.local/bin/kc`

`make install` requires `xcodegen`, Xcode, and a configured Apple developer account in Xcode for code signing.

## Usage

### Set a key from stdin
```bash
printf '%s' "$OPENAI_API_KEY" | kc set OPENAI_API_KEY --stdin
```

### Set a key with a secure prompt
```bash
kc set OPENAI_API_KEY --prompt
```

### Force a synchronizable write
```bash
kc set OPENAI_API_KEY --prompt --sync-only
```

### Force a local-only write
```bash
printf '%s' "$OPENAI_API_KEY" | kc set OPENAI_API_KEY --stdin --local-only
```

### Get a key
```bash
kc get OPENAI_API_KEY
```

### Get a key silently (no error output)
```bash
kc get OPENAI_API_KEY --silent
```

### Delete a key
```bash
kc delete OPENAI_API_KEY
```

### List key names
```bash
kc list
kc list --status
```

### Migrate one existing local-only key to iCloud sync
```bash
kc migrate-to-sync OPENAI_API_KEY
```

### Migrate all existing local-only keys to iCloud sync
```bash
kc migrate-to-sync --all
```

### Help
```bash
kc help
```

## Security note

`kc set <KEY> <VALUE>` was removed intentionally. Passing secrets as command-line arguments leaks them into shell history, process lists, and terminal logs.

Use one of these instead:

- `--stdin` for scripts and pipes
- `--prompt` for interactive entry

## Integration with `.zshrc` / `.zshenv`

Add this to your `.zshrc` or `.zshenv` to automatically load API keys:

```bash
export OPENAI_API_KEY=$(kc get OPENAI_API_KEY --silent)
export ANTHROPIC_API_KEY=$(kc get ANTHROPIC_API_KEY --silent)
```

The `--silent` flag ensures no error messages are printed if keys don't exist.

## Building

Unsigned SwiftPM build:

```bash
make build
```

Signed app bundle build:

```bash
make build-signed
```

## Uninstall

```bash
make uninstall
```

## Clean build artifacts

```bash
make clean
```

## How it works

Keys are stored in the macOS Keychain as generic passwords with:

- Service: `kc-cli`
- Account: your key name (for example `OPENAI_API_KEY`)
- Attribute: `kSecAttrSynchronizable=true` for synced writes

Default `kc set` behavior:

1. reads the secret from stdin or a secure prompt
2. tries to write a synchronizable item
3. falls back to local-only storage if synchronizable writes are unavailable
4. prints a warning when fallback happens

`kc migrate-to-sync --all` scans existing local-only items for service `kc-cli`, rewrites them as synchronizable items, and removes the local-only copies after a successful sync-capable write.
