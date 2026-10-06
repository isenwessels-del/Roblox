--!strict
-- Reserved contract for the isolated post-launch trading implementation.
export type TradeOffer = { UserId: number, Items: {string}, Locked: boolean, Confirmed: boolean }
export type TradeSession = { Id: string, Offers: {TradeOffer}, Revision: number,
    Status: "Invited" | "Offering" | "Confirming" | "Completed" | "Cancelled", ConfirmAfter: number }
return {}
