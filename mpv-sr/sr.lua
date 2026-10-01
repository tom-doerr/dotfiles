-- Live 2x neural upscaling (vs-mlrt TensorRT, see sr.vpy) with a real-time gate.
--
-- The GPU can only push so many source pixels per second through the model
-- (measured on an idle GB10: ~16 MP/s for 2xLiveActionV1_SPAN fp16, about half
-- that while other CUDA jobs run). A source above the budget would stutter, so
-- the filter is only inserted when width*height*fps fits, and it is removed
-- again if the measured filter rate falls behind. Every decision is shown on
-- the OSD; nothing is switched silently.
--
-- Key: n = force on / off for the current file (forcing on skips both checks).

local mp = require "mp"
local options = require "mp.options"

local dir = mp.get_script_directory() or debug.getinfo(1, "S").source:match("@(.*/)") or "./"
if dir:sub(-1) ~= "/" then dir = dir .. "/" end

local o = {
    budget_mps = 13,     -- source megapixels per second the model may be asked for
    model = os.getenv("HOME") .. "/.local/share/vsmlrt/models/2xLiveActionV1_SPAN_490000.onnx",
    min_ratio = 0.9,     -- filter fps / source fps below this counts as "behind"
    behind_checks = 3,   -- consecutive 2 s checks behind before SR is removed
    grace = 10,          -- seconds after insertion that are not judged (engine load, A/V catch-up)
}
options.read_options(o, "sr")

local LABEL = "sr"
local active = false
local forced = false
local disabled = false  -- switched off for this file (by hand or by the watchdog)
local behind = 0
local last = nil        -- previous watchdog sample
local inserted_at = 0
local timer = nil

local function say(msg)
    mp.msg.info(msg)
    mp.osd_message("SR " .. msg, 5)
end

local function quote(s) return ("%%%d%%%s"):format(#s, s) end

local function remove()
    if not active then return end
    mp.commandv("vf", "remove", "@" .. LABEL)
    active = false
    if timer then timer:kill() timer = nil end
end

local function source()
    local p = mp.get_property_native("video-dec-params")
    if not p or not p.w then return nil end
    -- Untagged streams: same guess mpv makes (HD = bt.709, SD = bt.601), so the
    -- matrix sr.vpy converts with is the one mpv assumes for the result.
    if p.colormatrix == nil or p.colormatrix == "auto" then
        p.colormatrix = (p.w >= 1280 or p.h > 576) and "bt.709" or "bt.601"
    end
    return p, mp.get_property_number("container-fps")
end

-- Frames actually shown per second. estimated-vf-fps is no use here: it is
-- derived from timestamps and reads the nominal rate however slow the filter is.
-- A slow filter shows up as dropped frames (with audio) or a slow clock (without).
local function watchdog()
    if forced or not active then return end
    local now = { wall = mp.get_time(), pos = mp.get_property_number("time-pos"),
                  drops = mp.get_property_number("frame-drop-count", 0) }
    local prev, fps = last, mp.get_property_number("container-fps")
    last = now
    if now.wall - inserted_at < o.grace then return end
    if not prev or not now.pos or not prev.pos or not fps then return end
    local dwall, dpos = now.wall - prev.wall, now.pos - prev.pos
    if mp.get_property_bool("pause") or mp.get_property_bool("paused-for-cache")
        or mp.get_property_number("speed") ~= 1 or dpos <= 0 or dpos > 2 * dwall then
        behind = 0  -- paused, buffering or seeking: not a throughput sample
        return
    end
    local shown = (dpos * fps - (now.drops - prev.drops)) / dwall
    behind = shown < fps * o.min_ratio and behind + 1 or 0
    if behind >= o.behind_checks then
        remove()
        disabled = true
        say(("off: only %.0f of %.4g fps shown (GPU busy?), n = force on"):format(shown, fps))
    end
end

local function insert(p)
    -- vapoursynth needs frames in system memory
    local hw = mp.get_property("hwdec-current", "no")
    if hw ~= "no" and not hw:match("%-copy$") then mp.set_property("hwdec", "auto-copy") end
    local ud = (p.colormatrix or "?") .. "|" .. o.model
    mp.commandv("vf", "add", ("@%s:vapoursynth=file=%s:buffered-frames=3:concurrent-frames=2:user-data=%s")
        :format(LABEL, quote(dir .. "sr.vpy"), quote(ud)))
    active = true
    behind = 0
    last, inserted_at = nil, mp.get_time()
    timer = mp.add_periodic_timer(2, watchdog)
end

local function decide()
    if active or disabled then return end
    local p, fps = source()
    if not p then return end
    local desc = ("%dx%d@%.4g"):format(p.w, p.h, fps or 0)
    if p.gamma == "pq" or p.gamma == "hlg" then
        return say(("off: %s is HDR (%s), the model is SDR only"):format(desc, p.gamma))
    end
    if p.colormatrix ~= "bt.709" and p.colormatrix ~= "bt.601" then
        return say(("off: %s is %s, the model is bt.709/bt.601 only"):format(desc, tostring(p.colormatrix)))
    end
    if not forced then
        if not fps then return say("off: " .. desc .. " has no frame rate to budget against") end
        local mps = p.w * p.h * fps / 1e6
        if mps > o.budget_mps then
            return say(("off: %s needs %.0f MP/s, budget %g, n = force on"):format(desc, mps, o.budget_mps))
        end
    end
    insert(p)
    say(("on%s: %s -> %dx%d"):format(forced and " (forced)" or "", desc, p.w * 2, p.h * 2))
end

-- vf chains survive into the next playlist entry, so start each file clean.
mp.register_event("start-file", function()
    remove()
    forced, disabled = false, false
end)
mp.observe_property("video-dec-params", "native", function(_, v)
    if v and v.w then decide() end
end)

mp.add_key_binding("n", "sr-toggle", function()
    if active then
        remove()
        forced, disabled = false, true
        say("off (manual)")
    else
        forced, disabled = true, false
        decide()
    end
end)
