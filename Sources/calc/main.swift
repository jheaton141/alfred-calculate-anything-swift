import CalcCore
import Foundation

let env = ProcessInfo.processInfo.environment
let query = CommandLine.arguments.dropFirst().joined(separator: " ")
let context = Context(settings: Settings(environment: env), dataDir: DefaultEngine.dataDir(environment: env))
let output = await Engine(tools: DefaultEngine.tools()).run(query, context: context)
print(output.json())
