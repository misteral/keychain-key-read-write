# kc - Keychain CLI Tool

A lightweight Swift CLI tool for securely storing and retrieving API keys and secrets in the macOS Keychain with iCloud sync support.

## Features

- Store sensitive keys like API tokens in macOS Keychain
- Automatic iCloud Keychain sync across your Apple devices
- Simple command-line interface
- Silent mode for shell integration
- Secure storage with `kSecAttrSynchronizable`

## Installation

```bash
make install
```

This will build the binary in release mode and install it to `/usr/local/bin/kc`.

## Usage

### Set a key (creates or updates)
```bash
kc set OPENAI_API_KEY sk-1234567890
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

### Help
```bash
kc help
```

## Integration with .zshrc/.zshenv

Add this to your `.zshrc` or `.zshenv` to automatically load API keys:

```bash
export OPENAI_API_KEY=$(kc get OPENAI_API_KEY --silent)
export ANTHROPIC_API_KEY=$(kc get ANTHROPIC_API_KEY --silent)
```

The `--silent` flag ensures no error messages are printed if keys don't exist.

## Building

```bash
make build
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
- Account: Your key name (e.g., `OPENAI_API_KEY`)
- Attribute: `kSecAttrSynchronizable=true` (enables iCloud sync)

When iCloud Keychain is enabled, keys automatically sync across your Apple devices. If iCloud Keychain is disabled, keys are stored locally only.
