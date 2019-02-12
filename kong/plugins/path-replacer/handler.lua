local BasePlugin = require "kong.plugins.base_plugin"

local PathReplacerHandler = BasePlugin:extend()

PathReplacerHandler.PRIORITY = 2000

function PathReplacerHandler:new()
  PathReplacerHandler.super.new(self, "path-replacer")
end

function PathReplacerHandler:access(conf)
  PathReplacerHandler.super.access(self)

  if conf.say_hello then
    kong.log.debug('Hey!')

    kong.service.request.set_header('X-Upstream-Header', 'Hey Upstream!')
    kong.response.set_header('X-Downstream-Header', 'Hey Downstream!')
  else
    kong.log.debug('Bye!')

    kong.service.request.set_header('X-Upstream-Header', 'Bye Upstream!')
    kong.response.set_header('X-Downstream-Header', 'Bye Downstream!')
  end

end

return PathReplacerHandler
