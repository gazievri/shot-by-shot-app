/// The one place where the rules of the ritual are set.
nonisolated enum RitualRules {
    /// Temporary rule (November 13, 2026): every portion reviewed to the end earns a star,
    /// including the second and later ones of a day. `false` restores one star per day.
    /// Windows and nights always count days.
    static let starPerSession = true
}
