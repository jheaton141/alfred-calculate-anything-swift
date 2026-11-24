import CalcCore
import Foundation

let env = ProcessInfo.processInfo.environment
let query = CommandLine.arguments.dropFirst().joined(separator: " ")
let settings = Settings(environment: env)
let dataDir = DefaultEngine.dataDir(environment: env)
let context = Context(settings: settings, rates: RatesService(dataDir: dataDir, settings: settings), dataDir: dataDir)
let output = await Engine(tools: DefaultEngine.tools(settings: settings)).run(query, context: context)
print(output.json())
