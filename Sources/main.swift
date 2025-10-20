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
      kc set <KEY> <VALUE>         Set a key in the keychain (creates or updates)
      kc get <KEY> [--silent]      Get a key from the keychain
      kc delete <KEY>              Delete a key from the keychain

    Options:
      --silent                     Suppress error messages (use with get command)
      -v, --version                Show version information

    Examples:
      kc set OPENAI_API_KEY sk-1234567890
      kc get OPENAI_API_KEY
      kc get OPENAI_API_KEY --silent
      kc delete OPENAI_API_KEY

    Note: Keys are stored with kSecAttrSynchronizable=true,
          which means they sync to iCloud Keychain when available.
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

        do {
            try keychain.set(key: key, value: value)
            print("Successfully set '\(key)' in keychain")
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
