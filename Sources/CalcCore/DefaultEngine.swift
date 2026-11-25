import Foundation

public enum DefaultEngine {
    /// The tools in dispatch order. Ports register themselves here.
    public static func tools(settings: Settings = Settings()) -> [Tool] {
        var time = TimeOptions()
        if let id = settings.timezone, !["none", "default", "system", "auto"].contains(id.lowercased()) {
            if let zone = TimeZone(identifier: id) ?? ZoneResolver.resolve(id)?.zone { time.zone = zone } else { time.invalidZone = id }
        }
        if let format = settings.timeFormat { time.formats = [format] }
        return [TipTool(), VatTool(), PercentageTool(), DiscountTool(), InterestTool(), FractionTool(), PxEmRemTool(), DataStorageTool(), TimeTool(options: time), RadixTool(), UnitsTool(), CryptoTool(),
                CurrencyTool(), ColorTool(), MathTool()]
    }

    /// Where cached rates and settings live: alfred_workflow_data, else ./.data next to the working directory.
    public static func dataDir(environment env: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let p = env["alfred_workflow_data"], !p.isEmpty { return URL(fileURLWithPath: p, isDirectory: true) }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true).appendingPathComponent(".data")
    }
}
