# kc - Keychain CLI Tool

A lightweight Swift CLI tool for securely storing and retrieving API keys and secrets in the macOS Keychain with iCloud sync support.

## Features

- Store sensitive keys like API tokens in macOS Keychain
- Signed install with `keychain-access-groups` entitlement for synchronizable items
- Automatic iCloud Keychain sync across your Apple devices
- Simple command-line interface
- Local-only or sync-only write modes
- Migration command for existing local-only keys

## Installation

```bash
make install
```

This builds a signed macOS app bundle via Xcode, installs it to:

- App bundle: `~/.local/share/kc/kc.app`
- CLI wrapper: `~/.local/bin/kc`

`make install` requires `xcodegen`.

## Usage

### Set a key (creates or updates)
```bash
kc set OPENAI_API_KEY sk-1234567890
```

### Force a synchronizable write
```bash
kc set OPENAI_API_KEY sk-1234567890 --sync-only
```

### Force a local-only write
```bash
kc set OPENAI_API_KEY sk-1234567890 --local-only
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

1. tries to write a synchronizable item
2. falls back to local-only storage if synchronizable writes are unavailable
3. prints a warning when fallback happens

`kc migrate-to-sync --all` scans existing local-only items for service `kc-cli`, rewrites them as synchronizable items, and removes the local-only copies after a successful sync-capable write.
