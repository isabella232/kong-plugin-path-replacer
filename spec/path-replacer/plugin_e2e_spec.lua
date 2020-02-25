local kong_helpers = require "spec.helpers"
local test_helpers = require "kong_client.spec.test_helpers"

describe("PathReplacer", function()

  local kong_sdk, send_request, send_admin_request
  local service

  setup(function()
    assert(
      kong_helpers.start_kong({ plugins = "path-replacer" })
    )

    kong_sdk = test_helpers.create_kong_client()
    send_request = test_helpers.create_request_sender(kong_helpers.proxy_client())
    send_admin_request = test_helpers.create_request_sender(kong_helpers.admin_client())
  end)

  teardown(function()
    kong_helpers.stop_kong(nil)
  end)

  describe("Plugin config", function()

    before_each(function()
      kong_helpers.db:truncate()

      service = kong_sdk.services:create({
        name = "test-service",
        url = "http://mockbin:8080/request/~placeholder~"
      })
    end)

    context("when config params are given correctly", function()

      it("should create plugin successfully", function()
        local _, response = pcall(function()
          return kong_sdk.plugins:create({
            service = { id = service.id },
            name = "path-replacer",
            config = {
              source_header = "X-Something",
              placeholder = "~Anything~"
            }
          })
        end)

        assert.are.equal("X-Something", response.config.source_header)
        assert.are.equal("~Anything~", response.config.placeholder)
        assert.are.equal(false, response.config.log_only)
        assert.are.equal(" ", response.config.darklaunch_url)
      end)
    end)

    context("when config params are missing", function()

      it("should raise error", function()
        local _, response = pcall(function()
          return kong_sdk.plugins:create({
            service = { id = service.id },
            name = "path-replacer",
            config = {}
          })
        end)

        assert.are.equal("required field missing", response.body.fields.config["source_header"])
        assert.are.equal("required field missing", response.body.fields.config["placeholder"])
      end)
    end)

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
          service = { id = service.id },
          name = "path-replacer",
        })
      end)

      assert.is_equal(400, response.status)
    end)

    it("should interpolate the given header into the given placeholder", function()
      kong_sdk.plugins:create({
        service = { id = service.id },
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
        service = { id = service.id },
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
        service = { id = service.id },
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
        url = "http://mockbin:8080/request/"
      })

      kong_sdk.routes:create_for_service(service.id, "/test")
    end)

    it("should set X-Darklaunch-Replaced-Path header instead of rewriting the path", function()
      kong_sdk.plugins:create({
        service = { id = service.id },
        name = "path-replacer",
        config = {
          source_header = "X-Test-Header",
          placeholder = "~placeholder~",
          log_only = true,
          darklaunch_url = "/some-resource/some-item/~placeholder~/end"
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
      assert.is_equal("/some-resource/some-item/112233/end", response.body.headers["x-darklaunch-replaced-path"])
    end)
  end)
end)
