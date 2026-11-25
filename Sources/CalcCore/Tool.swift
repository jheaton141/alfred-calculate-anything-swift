import Foundation

/// Everything a tool needs to answer a query.
public struct Context {
    public var settings: Settings
    public var strings: Strings
    public var rates: RatesProviding?
    public var now: Date
    public var dataDir: URL

    public init(settings: Settings = Settings(), strings: Strings = .en, rates: RatesProviding? = nil, now: Date = Date(), dataDir: URL) {
        self.settings = settings; self.strings = strings; self.rates = rates; self.now = now; self.dataDir = dataDir
    }
}

/// A calculator. Returns nil when the query is not for this tool, so the engine tries the next one.
public protocol Tool {
    var name: String { get }
    func evaluate(_ query: String, context: Context) async -> [AlfredItem]?
}

/// Runs tools in order and returns the first non-nil answer.
public struct Engine {
    public var tools: [Tool]
    public init(tools: [Tool]) { self.tools = tools }

    public func run(_ rawQuery: String, context: Context) async -> AlfredOutput {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return AlfredOutput() }
        let q = ToolSupport.expandIndianMultipliers(trimmed, settings: context.settings)
        for tool in tools {
            if let items = await tool.evaluate(q, context: context) { return AlfredOutput(items: items) }
        }
        // A bare "10 lakh" has expanded to a plain number: show it.
        if q != trimmed, let v = NumberFormat.parse(q, settings: context.settings), v.isFinite {
            return AlfredOutput(items: [.value(title: ToolSupport.show(v, context.settings), copy: ToolSupport.show(v, context.settings), raw: ToolSupport.rawValue(v, context.settings), strings: context.strings)])
        }
        return AlfredOutput()
    }
}
