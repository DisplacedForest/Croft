import enum Domain.ClimateSource

struct SaveInputs: Equatable {
    var latitudeText: String
    var longitudeText: String
    var zoneSource: ClimateSource
    var frostDatesSource: ClimateSource
    var customZone: String?
    var customLastMonth: Int?
    var customLastDay: Int?
    var customFirstMonth: Int?
    var customFirstDay: Int?
}
