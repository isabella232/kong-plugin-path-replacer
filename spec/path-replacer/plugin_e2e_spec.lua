local cjson = require "cjson"
local kong_helpers = require "spec.helpers"
local test_helpers = require "kong_client.spec.test_helpers"

describe("PathReplacer", function()

  local kong_sdk, send_request, send_admin_request
  local service

  setup(function()
    kong_helpers.start_kong({ custom_plugins = "path-replacer" })
    kong_sdk = test_helpers.create_kong_client()
    send_request = test_helpers.create_request_sender(kong_helpers.proxy_client())
    send_admin_request = test_helpers.create_request_sender(kong_helpers.admin_client())
  end)

  teardown(function()
    kong_helpers.stop_kong(nil)
  end)

  before_each(function()
    kong_helpers.db:truncate()

    service = kong_sdk.services:create({
      name = "MockBin",
      url = "http://mockbin:8080/request/~customer_id~"
    })

    kong_sdk.routes:create_for_service(service.id, "/test")
  end)

  it("should interpolate the X-Suite-CustomerId header into the ~customer_id~ placeholder", function()
    kong_sdk.plugins:create({
      service_id = service.id,
      name = "path-replacer"
    })

    local response = send_request({
      method = "GET",
      path = "/test/some-resource-path",
      headers = {
        ["X-Suite-CustomerId"] = "112233"
      }
    })

    assert.is_equal("http://0.0.0.0/request/112233/some-resource-path", response.body.url)
  end)

  it("should not interpolate when X-Suite-CustomerId header is not present", function()
    kong_sdk.plugins:create({
      service_id = service.id,
      name = "path-replacer"
    })

    local response = send_request({
      method = "GET",
      path = "/test/some-resource-path"
    })

    assert.is_equal("http://0.0.0.0/request/~customer_id~/some-resource-path", response.body.url)
  end)
end)
