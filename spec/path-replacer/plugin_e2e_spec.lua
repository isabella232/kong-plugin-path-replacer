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

  it('should interpolate the X-Suite-CustomerId header into the ~customer_id~ placeholder', function()
    local service_creation_call = assert(helpers.admin_client():send({
      method = 'POST',
      path = '/services',
      body = {
        name = 'MockBin',
        url = 'http://mockbin:8080/request/~customer_id~'
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
      },
      headers = {
        ['Content-Type'] = 'application/json'
      }
    }))

    assert.res_status(201, plugin_creation_call)

    local client_call = assert(helpers.proxy_client():send({
      method = 'GET',
      path = '/test/some-resource-path',
      headers = {
        ["X-Suite-CustomerId"] = "112233"
      }
    }))

    local client_response_data = cjson.decode(
      assert.res_status(200, client_call)
    )

    assert.is_equal('http://0.0.0.0/request/112233/some-resource-path', client_response_data.url)
  end)

  it('should not interpolate when X-Suite-CustomerId header is not present', function()
    local service_creation_call = assert(helpers.admin_client():send({
      method = 'POST',
      path = '/services',
      body = {
        name = 'MockBin',
        url = 'http://mockbin:8080/request/~customer_id~'
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
      },
      headers = {
        ['Content-Type'] = 'application/json'
      }
    }))

    assert.res_status(201, plugin_creation_call)

    local client_call = assert(helpers.proxy_client():send({
      method = 'GET',
      path = '/test/some-resource-path'
    }))

    local client_response_data = cjson.decode(
      assert.res_status(200, client_call)
    )

    assert.is_equal('http://0.0.0.0/request/~customer_id~/some-resource-path', client_response_data.url)
  end)
end)
