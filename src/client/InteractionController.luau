--!nonstrict
local ProximityPromptService = game:GetService("ProximityPromptService")
local W = require(script.Parent.Widgets)
local Interaction = {}
Interaction.__index = Interaction

function Interaction.new(ctx)
    local self = setmetatable({ Context = ctx, Highlights = {} }, Interaction)
    -- Native prompts support keyboard, touch and console. Their Triggered callbacks
    -- remain on the server; this controller adds only a local focus outline.
    ProximityPromptService.PromptShown:Connect(function(prompt)
        local state = ctx.State
        if state and state.Profile.Settings.ReducedEffects then return end
        local parent = prompt.Parent
        if not parent then return end
        local target = parent:FindFirstAncestorWhichIsA("Model") or parent
        if not target:IsA("Model") and not target:IsA("BasePart") then return end
        local highlight = Instance.new("Highlight")
        highlight.Name, highlight.Adornee = "LocalInteractionFocus", target
        highlight.FillColor, highlight.OutlineColor = W.Colors.Teal, W.Colors.Orange
        highlight.FillTransparency, highlight.OutlineTransparency = 0.92, 0.2
        highlight.DepthMode = Enum.HighlightDepthMode.Occluded
        highlight.Parent = target
        self.Highlights[prompt] = highlight
    end)
    ProximityPromptService.PromptHidden:Connect(function(prompt)
        local highlight = self.Highlights[prompt]
        if highlight then highlight:Destroy(); self.Highlights[prompt] = nil end
    end)
    return self
end

return Interaction
