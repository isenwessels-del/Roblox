--!strict
-- Real IDs are configured only after publishing. Zero IDs never prompt purchases.
-- Entitlements are cosmetic only. Marketplace ownership/receipts must be checked on the server.
return {
    Enabled = false,
    Gamepasses = {
        GoldenName = { Id = 0, Name = "Golden Name", Cosmetic = "GoldenName" },
        VIPTheme = { Id = 0, Name = "VIP House Theme", Cosmetic = "VIPTheme" },
    },
    DeveloperProducts = {},
    Cosmetics = {
        GoldenName = { Type = "NameColor", Color = "#FFD566" },
        VIPTheme = { Type = "HouseTheme", Theme = "Midnight" },
    },
    UnknownReceiptBehavior = "NotProcessedYet",
}
