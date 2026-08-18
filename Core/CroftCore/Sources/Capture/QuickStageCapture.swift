import Foundation

import enum Domain.LifecycleStage
import struct Domain.Planting

public enum QuickStageCapture {
    @discardableResult
    public static func record(
        _ stage: LifecycleStage,
        on plantingID: Planting.ID,
        context: CaptureContext,
        now: Date = Date()
    ) throws -> ObservationRecord {
        let form = LogObservationForm(context: context, target: .planting(plantingID), now: now)
        form.stage = stage
        return try form.save()
    }
}
