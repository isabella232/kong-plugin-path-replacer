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

  context("When placeholder is present in service url", function()
    before_each(function()
      kong_helpers.db:truncate()

      service = kong_sdk.services:create({
        name = "MockBin",
        url = "http://mockbin:8080/request/~placeholder~"
      })

      kong_sdk.routes:create_for_service(service.id, "/test")
    end)

    it("should require source_header and placeholder config parameters", function()
      local success, response = pcall(function()
        kong_sdk.plugins:create({
          service_id = service.id,
          name = "path-replacer",
        })
      end)

      assert.is_equal(400, response.status)
    end)

    it("should interpolate the given header into the given placeholder", function()
      kong_sdk.plugins:create({
        service_id = service.id,
        name = "path-replacer",
        config = {
          source_header = "X-Test-Header",
          placeholder = "~placeholder~"
        }
      })

      local response = send_request({
        method = "GET",
        path = "/test/some-resource-path",
        headers = {
          ["X-Test-Header"] = "112233"
        }
      })

      assert.is_equal("http://0.0.0.0/request/112233/some-resource-path", response.body.url)
    end)

    it("should not interpolate when the given header is not present", function()
      kong_sdk.plugins:create({
        service_id = service.id,
        name = "path-replacer",
        config = {
          source_header = "X-Test-Header",
          placeholder = "~placeholder~"
        }
      })

      local response = send_request({
        method = "GET",
        path = "/test/some-resource-path"
      })

      assert.is_equal("http://0.0.0.0/request/~placeholder~/some-resource-path", response.body.url)
    end)
  end)

  context("When placeholder is not present in service url", function()
    before_each(function()
      kong_helpers.db:truncate()

      service = kong_sdk.services:create({
        name = "MockBin",
        url = "http://mockbin:8080/request/"
      })

      kong_sdk.routes:create_for_service(service.id, "/test")
    end)

    it("should not explode", function()
      kong_sdk.plugins:create({
        service_id = service.id,
        name = "path-replacer",
        config = {
          source_header = "X-Test-Header",
          placeholder = "~placeholder~"
        }
      })

      local response = send_request({
        method = "GET",
        path = "/test/some-resource-path",
        headers = {
          ["X-Test-Header"] = "112233"
        }
      })

      assert.is_equal("http://0.0.0.0/request/some-resource-path", response.body.url)
    end)
  end)

  context("When log_only is enabled", function()
    before_each(function()
      kong_helpers.db:truncate()

      service = kong_sdk.services:create({
        name = "MockBin",
        url = "http://mockbin:8080/request/~placeholder~"
      })

      kong_sdk.routes:create_for_service(service.id, "/test")
    end)

    it("should set X-Darklaunch-Replaced-Path header instead of rewriting the path", function()
      kong_sdk.plugins:create({
        service_id = service.id,
        name = "path-replacer",
        config = {
          source_header = "X-Test-Header",
          placeholder = "~placeholder~",
          log_only = true
        }
      })

      local response = send_request({
        method = "GET",
        path = "/test/some-resource-path",
        headers = {
          ["X-Test-Header"] = "112233"
        }
      })

      assert.is_equal("http://0.0.0.0/request/~placeholder~/some-resource-path", response.body.url)
      assert.is_equal("/request/112233/some-resource-path", response.body.headers["x-darklaunch-replaced-path"])
    end)
  end)
end)
