/// Settings visibility affects window ordering, never whether a ready effect can render.
public struct EffectPresentationPolicy {
    public let canRender: Bool
    public let keepSettingsAboveEffect: Bool

    public init(enabled: Bool, hasFrame: Bool, hasAngle: Bool, settingsVisible: Bool) {
        canRender = enabled && hasFrame && hasAngle
        keepSettingsAboveEffect = canRender && settingsVisible
    }
}
