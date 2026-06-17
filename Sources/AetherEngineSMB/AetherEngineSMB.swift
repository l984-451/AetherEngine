// AetherEngineSMB: opt-in SMB2/3 byte source for AetherEngine.
// Depends on AMSMB2 (libsmb2, LGPL-2.1). Linked only by consumers that
// link the AetherEngineSMB product; never enters the core engine binary.

/// Marker for the AetherEngineSMB module version surface.
public enum AetherEngineSMB {
    public static let isAvailable = true
}
