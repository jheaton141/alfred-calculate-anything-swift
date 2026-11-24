import CalcCore
import Foundation

let env = ProcessInfo.processInfo.environment
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--refresh"] || arguments == ["--refresh", "--check"] {
    let refreshSettings = RatesRefresh.forcing(Settings(environment: env))
    let summary = await RatesRefresh.run(RatesService(dataDir: DefaultEngine.dataDir(environment: env), settings: refreshSettings))
    print(summary)
    // --check reports a failed refresh in the exit code; plain --refresh (Alfred) always exits 0 so the message shows
    exit(arguments.contains("--check") && RatesRefresh.failed(summary) ? 1 : 0)
}
let query = CommandLine.arguments.dropFirst().joined(separator: " ")
let settings = Settings(environment: env)
let dataDir = DefaultEngine.dataDir(environment: env)
let context = Context(settings: settings, strings: Strings.load(settings.language), rates: RatesService(dataDir: dataDir, settings: settings), dataDir: dataDir)
let output = await Engine(tools: DefaultEngine.tools(settings: settings)).run(query, context: context)
print(output.json())
