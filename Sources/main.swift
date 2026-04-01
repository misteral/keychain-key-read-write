import Foundation

enum ExitCode: Int32 {
    case success = 0
    case error = 1
    case invalidArguments = 2
}

func printVersion() {
    print("kc version \(version)")
}

func printUsage() {
    print("""
    Usage:
      kc set <KEY> <VALUE> [--sync-only|--local-only]
                                   Set a key in the keychain (creates or updates)
      kc get <KEY> [--silent]       Get a key from the keychain
      kc delete <KEY>               Delete a key from the keychain
      kc list [--status]            List stored key names
      kc migrate-to-sync <KEY>      Rewrite a local-only key as synchronizable
      kc migrate-to-sync --all      Rewrite all local-only keys as synchronizable

    Options:
      --silent                      Suppress error messages (use with get command)
      --sync-only                   Fail if synchronizable write is unavailable
      --local-only                  Store only in the local login keychain
      -v, --version                 Show version information

    Examples:
      kc set OPENAI_API_KEY sk-1234567890
      kc set OPENAI_API_KEY sk-1234567890 --sync-only
      kc get OPENAI_API_KEY
      kc get OPENAI_API_KEY --silent
      kc delete OPENAI_API_KEY
      kc list
      kc list --status
      kc migrate-to-sync OPENAI_API_KEY
      kc migrate-to-sync --all

    Note: In the signed install, keys are stored as synchronizable keychain items
          and sync through iCloud Keychain when available.
    """)
}

func main() {
    let arguments = Array(CommandLine.arguments.dropFirst())

    guard !arguments.isEmpty else {
        printUsage()
        exit(ExitCode.invalidArguments.rawValue)
    }

    let command = arguments[0]
    let keychain = KeychainManager()

    switch command {
    case "set":
        guard arguments.count >= 3 else {
            fputs("Error: 'set' command requires KEY and VALUE arguments\n", stderr)
            printUsage()
            exit(ExitCode.invalidArguments.rawValue)
        }

        let key = arguments[1]
        let value = arguments[2]
        let syncOnly = arguments.contains("--sync-only")
        let localOnly = arguments.contains("--local-only")

        guard !(syncOnly && localOnly) else {
            fputs("Error: use only one of --sync-only or --local-only\n", stderr)
            exit(ExitCode.invalidArguments.rawValue)
        }

        let mode: StorageMode = if syncOnly {
            .synchronizableOnly
        } else if localOnly {
            .localOnly
        } else {
            .synchronizableWithFallback
        }

        do {
            let result = try keychain.set(key: key, value: value, mode: mode)
            switch result {
            case .synchronizable:
                print("Successfully set '\(key)' in iCloud-synced keychain")
            case .localFallback:
                print("Successfully set '\(key)' in local keychain")
                fputs("Warning: synchronizable write was unavailable, so the key was stored locally only\n", stderr)
            case .localOnly:
                print("Successfully set '\(key)' in local keychain")
            }
            exit(ExitCode.success.rawValue)
        } catch {
            fputs("Error: Failed to set key - \(error)\n", stderr)
            exit(ExitCode.error.rawValue)
        }

    case "get":
        guard arguments.count >= 2 else {
            fputs("Error: 'get' command requires KEY argument\n", stderr)
            printUsage()
            exit(ExitCode.invalidArguments.rawValue)
        }

        let key = arguments[1]
        let silent = arguments.contains("--silent")

        do {
            let value = try keychain.get(key: key)
            print(value)
            exit(ExitCode.success.rawValue)
        } catch KeychainError.itemNotFound {
            if !silent {
                fputs("Error: Key '\(key)' not found in keychain\n", stderr)
            }
            exit(ExitCode.error.rawValue)
        } catch {
            if !silent {
                fputs("Error: Failed to get key - \(error)\n", stderr)
            }
            exit(ExitCode.error.rawValue)
        }

    case "delete":
        guard arguments.count >= 2 else {
            fputs("Error: 'delete' command requires KEY argument\n", stderr)
            printUsage()
            exit(ExitCode.invalidArguments.rawValue)
        }

        let key = arguments[1]

        do {
            try keychain.delete(key: key)
            print("Successfully deleted '\(key)' from keychain")
            exit(ExitCode.success.rawValue)
        } catch KeychainError.itemNotFound {
            fputs("Error: Key '\(key)' not found in keychain\n", stderr)
            exit(ExitCode.error.rawValue)
        } catch {
            fputs("Error: Failed to delete key - \(error)\n", stderr)
            exit(ExitCode.error.rawValue)
        }

    case "list":
        let showStatus = arguments.contains("--status")

        do {
            if showStatus {
                let statuses = try keychain.listStatuses()

                if statuses.isEmpty {
                    print("No keys found for service 'kc-cli'")
                } else {
                    let maxKeyLength = statuses.map { $0.key.count }.max() ?? 3
                    let keyWidth = max(maxKeyLength, 3)

                    func padded(_ value: String, to width: Int) -> String {
                        value.padding(toLength: width, withPad: " ", startingAt: 0)
                    }

                    print("\(padded("KEY", to: keyWidth))  STATUS")
                    for item in statuses {
                        print("\(padded(item.key, to: keyWidth))  \(item.statusLabel)")
                    }
                }
            } else {
                let localKeys = try keychain.listLocalKeys()
                let syncKeys = try keychain.listSynchronizableKeys()
                let keys = Array(Set(localKeys).union(syncKeys)).sorted()

                if keys.isEmpty {
                    print("No keys found for service 'kc-cli'")
                } else {
                    for key in keys {
                        print(key)
                    }
                }
            }

            exit(ExitCode.success.rawValue)
        } catch {
            fputs("Error: Failed to list keys - \(error)\n", stderr)
            exit(ExitCode.error.rawValue)
        }

    case "migrate-to-sync":
        guard arguments.count >= 2 else {
            fputs("Error: 'migrate-to-sync' requires KEY or --all\n", stderr)
            printUsage()
            exit(ExitCode.invalidArguments.rawValue)
        }

        if arguments[1] == "--all" {
            do {
                let migratedKeys = try keychain.migrateAllLocalItemsToSync()

                if migratedKeys.isEmpty {
                    print("No local-only keys found for service 'kc-cli'")
                } else {
                    print("Migrated \(migratedKeys.count) key(s) to iCloud-synced keychain:")
                    for key in migratedKeys {
                        print("- \(key)")
                    }
                }

                exit(ExitCode.success.rawValue)
            } catch {
                fputs("Error: Failed to migrate keys - \(error)\n", stderr)
                exit(ExitCode.error.rawValue)
            }
        }

        let key = arguments[1]

        do {
            try keychain.migrateToSync(key: key)
            print("Migrated '\(key)' to iCloud-synced keychain")
            exit(ExitCode.success.rawValue)
        } catch KeychainError.itemNotFound {
            fputs("Error: Local-only key '\(key)' not found\n", stderr)
            exit(ExitCode.error.rawValue)
        } catch {
            fputs("Error: Failed to migrate key - \(error)\n", stderr)
            exit(ExitCode.error.rawValue)
        }

    case "help", "--help", "-h":
        printUsage()
        exit(ExitCode.success.rawValue)

    case "version", "--version", "-v":
        printVersion()
        exit(ExitCode.success.rawValue)

    default:
        fputs("Error: Unknown command '\(command)'\n", stderr)
        printUsage()
        exit(ExitCode.invalidArguments.rawValue)
    }
}

main()
