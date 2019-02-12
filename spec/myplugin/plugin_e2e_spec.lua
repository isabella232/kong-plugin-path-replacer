local helpers = require "spec.helpers"
local cjson = require "cjson"

describe("PathReplacer", function()
  setup(function()
    helpers.start_kong({ custom_plugins = 'path-replacer' })
  end)

  teardown(function()
    helpers.stop_kong(nil)
  end)

  before_each(function()
    helpers.db:truncate()
  end)

  context('when the "say_hello" flag is true', function()
    it('should add headers to the proxied request', function()
      local service_creation_call = assert(helpers.admin_client():send({
        method = 'POST',
        path = '/services',
        body = {
          name = 'MockBin',
          url = 'http://mockbin:8080/request'
        },
        headers = {
          ['Content-Type'] = 'application/json'
        }
      }))

      local service_creation_data = cjson.decode(
        assert.res_status(201, service_creation_call)
      )

      local service_id = service_creation_data.id

      local route_creation_call = assert(helpers.admin_client():send({
        method = 'POST',
        path = '/services/' .. service_id .. '/routes',
        body = {
          paths = {
            '/test'
          }
        },
        headers = {
          ['Content-Type'] = 'application/json'
        }
      }))

      assert.res_status(201, route_creation_call)

      local plugin_creation_call = assert(helpers.admin_client():send({
        method = 'POST',
        path = '/services/' .. service_id .. '/plugins',
        body = {
          name = 'path-replacer',
          config = {
            say_hello = true
          }
        },
        headers = {
          ['Content-Type'] = 'application/json'
        }
      }))

      assert.res_status(201, plugin_creation_call)

      local client_call = assert(helpers.proxy_client():send({
        method = 'GET',
        path = '/test'
      }))

      local client_response_data = cjson.decode(
        assert.res_status(200, client_call)
      )

      assert.is_equal('Hey Upstream!', client_response_data.headers['x-upstream-header'])
      assert.response(client_call).has.header('X-Downstream-Header')
      assert.is_equal('Hey Downstream!', client_call.headers['X-Downstream-Header'])
    end)
  end)

  context('when the "say_hello" flag is false', function()
    it('should add headers to the proxied request', function()
      local service_creation_call = assert(helpers.admin_client():send({
        method = 'POST',
        path = '/services',
        body = {
          name = 'MockBin',
          url = 'http://mockbin:8080/request'
        },
        headers = {
          ['Content-Type'] = 'application/json'
        }
      }))

      local service_creation_data = cjson.decode(
        assert.res_status(201, service_creation_call)
      )

      local service_id = service_creation_data.id

      local route_creation_call = assert(helpers.admin_client():send({
        method = 'POST',
        path = '/services/' .. service_id .. '/routes',
        body = {
          paths = {
            '/test'
          }
        },
        headers = {
          ['Content-Type'] = 'application/json'
        }
      }))

      assert.res_status(201, route_creation_call)

      local plugin_creation_call = assert(helpers.admin_client():send({
        method = 'POST',
        path = '/services/' .. service_id .. '/plugins',
        body = {
          name = 'path-replacer',
          config = {
            say_hello = false
          }
        },
        headers = {
          ['Content-Type'] = 'application/json'
        }
      }))

      assert.res_status(201, plugin_creation_call)

      local client_call = assert(helpers.proxy_client():send({
        method = 'GET',
        path = '/test'
      }))

      local client_response_data = cjson.decode(
        assert.res_status(200, client_call)
      )

      assert.is_equal('Bye Upstream!', client_response_data.headers['x-upstream-header'])
      assert.response(client_call).has.header('X-Downstream-Header')
      assert.is_equal('Bye Downstream!', client_call.headers['X-Downstream-Header'])
    end)
  end)
end)
