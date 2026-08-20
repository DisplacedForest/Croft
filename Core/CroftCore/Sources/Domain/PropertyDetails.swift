public struct PropertyDetails: Equatable, Sendable {
    public var location: GeoCoordinate?
    public var hardinessZone: HardinessZone?
    public var lastFrost: MonthDay?
    public var firstFrost: MonthDay?
    public var zoneSource: ClimateSource
    public var frostDatesSource: ClimateSource

    public init(
        location: GeoCoordinate? = nil,
        hardinessZone: HardinessZone? = nil,
        lastFrost: MonthDay? = nil,
        firstFrost: MonthDay? = nil,
        zoneSource: ClimateSource = .derived,
        frostDatesSource: ClimateSource = .derived
    ) {
        self.location = location
        self.hardinessZone = hardinessZone
        self.lastFrost = lastFrost
        self.firstFrost = firstFrost
        self.zoneSource = zoneSource
        self.frostDatesSource = frostDatesSource
    }
}
