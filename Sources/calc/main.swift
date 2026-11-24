import CalcCore
import Foundation

let env = ProcessInfo.processInfo.environment
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--refresh"] {
    let refreshSettings = RatesRefresh.forcing(Settings(environment: env))
    print(await RatesRefresh.run(RatesService(dataDir: DefaultEngine.dataDir(environment: env), settings: refreshSettings)))
    exit(0)
}
let query = CommandLine.arguments.dropFirst().joined(separator: " ")
let settings = Settings(environment: env)
let dataDir = DefaultEngine.dataDir(environment: env)
let context = Context(settings: settings, strings: Strings.load(settings.language), rates: RatesService(dataDir: dataDir, settings: settings), dataDir: dataDir)
let output = await Engine(tools: DefaultEngine.tools(settings: settings)).run(query, context: context)
print(output.json())
