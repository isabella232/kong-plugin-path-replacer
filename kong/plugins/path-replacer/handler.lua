local BasePlugin = require "kong.plugins.base_plugin"

local PathReplacerHandler = BasePlugin:extend()

PathReplacerHandler.PRIORITY = 2000

function PathReplacerHandler:new()
  PathReplacerHandler.super.new(self, "path-replacer")
end

function PathReplacerHandler:access(conf)
  PathReplacerHandler.super.access(self)

  local replacement = kong.request.get_header(conf.source_header)

  if not replacement then return end

  local upstream_uri = ngx.var.upstream_uri:gsub(conf.placeholder, replacement)

  if conf.log_only then
    kong.service.request.set_header("X-Darklaunch-Replaced-Path", upstream_uri)
  else
    kong.service.request.set_path(upstream_uri)
  end
end

return PathReplacerHandler
