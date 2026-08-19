import Foundation

public enum PlantingWindowField: String, CaseIterable, Hashable, Sendable {
    case lastFrost
    case sowingMethod
    case frostTolerance
    case weeksIndoorsBeforeTransplant
}

public enum SowingAction: CaseIterable, Hashable, Sendable {
    case sowIndoors
    case directSow
    case transplantOut
}

public struct SowingOpportunity: Equatable, Sendable {
    public let action: SowingAction
    public let window: ClosedRange<Date>
}

public enum PlantingWindowAssessment: Equatable, Sendable {
    case act(SowingOpportunity)
    case upcoming(SowingOpportunity)
    case notApplicable
    case cannotAssess([PlantingWindowField])
}

public struct PlantingWindowProfile: Equatable, Sendable {
    public let sowingMethod: SowingMethod?
    public let frostTolerance: FrostTolerance?
    public let weeksIndoorsBeforeTransplant: ClosedRange<Int>?
    public let daysToMaturity: ClosedRange<Int>?
    public let daysToMaturityBasis: DaysToMaturityBasis?
    public let germinationTempMin: Double?

    public init(
        sowingMethod: SowingMethod? = nil,
        frostTolerance: FrostTolerance? = nil,
        weeksIndoorsBeforeTransplant: ClosedRange<Int>? = nil,
        daysToMaturity: ClosedRange<Int>? = nil,
        daysToMaturityBasis: DaysToMaturityBasis? = nil,
        germinationTempMin: Double? = nil
    ) {
        self.sowingMethod = sowingMethod
        self.frostTolerance = frostTolerance
        self.weeksIndoorsBeforeTransplant = weeksIndoorsBeforeTransplant
        self.daysToMaturity = daysToMaturity
        self.daysToMaturityBasis = daysToMaturityBasis
        self.germinationTempMin = germinationTempMin
    }

    public init(species: Species, cultivar: Cultivar? = nil) {
        self.init(
            sowingMethod: species.sowingMethod,
            frostTolerance: species.frostTolerance,
            weeksIndoorsBeforeTransplant: species.weeksIndoorsBeforeTransplant,
            daysToMaturity: cultivar?.daysToMaturity ?? species.daysToMaturity,
            daysToMaturityBasis: species.daysToMaturityBasis,
            germinationTempMin: species.germinationTempMin
        )
    }
}

public struct FrostAnchors: Equatable, Sendable {
    public let lastFrost: MonthDay?
    public let firstFrost: MonthDay?

    public init(lastFrost: MonthDay?, firstFrost: MonthDay?) {
        self.lastFrost = lastFrost
        self.firstFrost = firstFrost
    }

    public init(property: Property) {
        self.init(lastFrost: property.lastFrost, firstFrost: property.firstFrost)
    }
}

public enum PlantingWindows {
    public static let hardyOffsetDays = -28
    public static let halfHardyOffsetDays = -14
    public static let tenderOffsetDays = 0
    public static let transplantWindowDays = 21
    public static let defaultDirectWindowDays = 56
    public static let upcomingHorizonDays = 366

    public static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    public static func assess(
        _ profile: PlantingWindowProfile,
        anchors: FrostAnchors,
        on reference: Date,
        calendar: Calendar = utcCalendar
    ) -> PlantingWindowAssessment {
        if profile.sowingMethod == .plantingStock {
            return .notApplicable
        }
        let missing = missingFields(profile: profile, anchors: anchors)
        if !missing.isEmpty {
            return .cannotAssess(missing)
        }
        let opportunities = candidateWindows(
            profile: profile,
            anchors: anchors,
            reference: reference,
            calendar: calendar
        )

        let open =
            opportunities
            .filter { $0.window.contains(reference) }
            .min { $0.window.upperBound < $1.window.upperBound }
        if let open {
            return .act(open)
        }
        guard
            let horizon = calendar.date(byAdding: .day, value: upcomingHorizonDays, to: reference)
        else {
            return .notApplicable
        }
        let next =
            opportunities
            .filter { $0.window.lowerBound > reference && $0.window.lowerBound <= horizon }
            .min { $0.window.lowerBound < $1.window.lowerBound }
        if let next {
            return .upcoming(next)
        }
        return .notApplicable
    }

    private static func candidateWindows(
        profile: PlantingWindowProfile,
        anchors: FrostAnchors,
        reference: Date,
        calendar: Calendar
    ) -> [SowingOpportunity] {
        guard
            let lastFrost = anchors.lastFrost,
            let method = profile.sowingMethod,
            let tolerance = profile.frostTolerance
        else {
            return []
        }
        var opportunities: [SowingOpportunity] = []
        for yearOffset in [-1, 0, 1] {
            guard
                let anchor = nearestAnchor(
                    of: lastFrost, to: reference, yearOffset: yearOffset, calendar: calendar),
                let safeDate = calendar.date(
                    byAdding: .day, value: offsetDays(for: tolerance), to: anchor)
            else {
                continue
            }
            let firstFrostDate = firstFrostDate(after: anchor, anchors: anchors, calendar: calendar)
            opportunities.append(
                contentsOf: windows(
                    profile: profile,
                    method: method,
                    safeDate: safeDate,
                    firstFrostDate: firstFrostDate,
                    calendar: calendar
                ))
        }
        return opportunities
    }

    public static func offsetDays(for tolerance: FrostTolerance) -> Int {
        switch tolerance {
        case .hardy: hardyOffsetDays
        case .halfHardy: halfHardyOffsetDays
        case .tender: tenderOffsetDays
        }
    }

    static func missingFields(
        profile: PlantingWindowProfile,
        anchors: FrostAnchors
    ) -> [PlantingWindowField] {
        var missing: [PlantingWindowField] = []
        if anchors.lastFrost == nil {
            missing.append(.lastFrost)
        }
        if profile.sowingMethod == nil {
            missing.append(.sowingMethod)
        }
        if profile.frostTolerance == nil {
            missing.append(.frostTolerance)
        }
        let wantsIndoors = profile.sowingMethod == .transplant || profile.sowingMethod == .both
        if wantsIndoors, profile.weeksIndoorsBeforeTransplant == nil {
            missing.append(.weeksIndoorsBeforeTransplant)
        }
        return missing
    }

    private static func indoorWindow(
        weeks: ClosedRange<Int>,
        safeDate: Date,
        calendar: Calendar
    ) -> SowingOpportunity? {
        guard
            let start = calendar.date(
                byAdding: .day, value: -weeks.upperBound * 7, to: safeDate),
            let end = calendar.date(
                byAdding: .day, value: -weeks.lowerBound * 7, to: safeDate),
            start <= end
        else {
            return nil
        }
        return SowingOpportunity(action: .sowIndoors, window: start...end)
    }

    private static func windows(
        profile: PlantingWindowProfile,
        method: SowingMethod,
        safeDate: Date,
        firstFrostDate: Date?,
        calendar: Calendar
    ) -> [SowingOpportunity] {
        var result: [SowingOpportunity] = []
        let raisesTransplants = method == .transplant || method == .both

        if raisesTransplants, let weeks = profile.weeksIndoorsBeforeTransplant {
            if let indoors = indoorWindow(weeks: weeks, safeDate: safeDate, calendar: calendar) {
                result.append(indoors)
            }
            let transplantEnd = calendar.date(
                byAdding: .day, value: transplantWindowDays, to: safeDate)
            if let transplantEnd {
                result.append(
                    SowingOpportunity(action: .transplantOut, window: safeDate...transplantEnd))
            }
        }

        if method == .direct || method == .both {
            var end: Date?
            if let firstFrostDate {
                end = firstFrostDate
                let basis = profile.daysToMaturityBasis
                let countsBackFromFrost = basis != .fromTransplant && basis != .fromPlantingStock
                if let maturity = profile.daysToMaturity, countsBackFromFrost {
                    end = calendar.date(
                        byAdding: .day, value: -maturity.upperBound, to: firstFrostDate)
                }
            } else {
                end = calendar.date(
                    byAdding: .day, value: defaultDirectWindowDays, to: safeDate)
            }
            if let end, safeDate <= end {
                result.append(SowingOpportunity(action: .directSow, window: safeDate...end))
            }
        }
        return result
    }

    static func nearestAnchor(
        of monthDay: MonthDay,
        to reference: Date,
        yearOffset: Int,
        calendar: Calendar
    ) -> Date? {
        let year = calendar.component(.year, from: reference) + yearOffset
        return date(of: monthDay, year: year, calendar: calendar)
    }

    static func firstFrostDate(
        after lastFrostDate: Date,
        anchors: FrostAnchors,
        calendar: Calendar
    ) -> Date? {
        guard let firstFrost = anchors.firstFrost else {
            return nil
        }
        let year = calendar.component(.year, from: lastFrostDate)
        for candidateYear in [year, year + 1] {
            let candidate = date(of: firstFrost, year: candidateYear, calendar: calendar)
            if let candidate, candidate > lastFrostDate {
                return candidate
            }
        }
        return nil
    }

    static func date(of monthDay: MonthDay, year: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = monthDay.month
        components.day = monthDay.day
        guard let resolved = calendar.date(from: components) else {
            return nil
        }
        if calendar.component(.month, from: resolved) != monthDay.month {
            components.day = monthDay.day - 1
            return calendar.date(from: components)
        }
        return resolved
    }
}
