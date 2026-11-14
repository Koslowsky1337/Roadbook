UNKNOWN = {}
setmetatable(_G, { __index = function(t, k) UNKNOWN[k] = true; return nil end })
