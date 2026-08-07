-- Stub loader so we can track load calls without side effects
local load_calls = {}
package.loaded["code-workspace.loader"] = {
    load   = function(ws) table.insert(load_calls, ws) end,
    close  = function() end,
    active = function() return nil end,
}

local detector

describe("detector._scan", function()
    before_each(function()
        load_calls = {}
        package.loaded["code-workspace.detector"] = nil
        detector = require("code-workspace.detector")
    end)

    it("returns empty table when no .code-workspace files found", function()
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        local files = detector._scan(dir, 0)
        assert.same({}, files)
    end)

    it("finds a .code-workspace file in the given directory", function()
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        local ws_path = dir .. "/test.code-workspace"
        io.open(ws_path, "w"):close()
        local files = detector._scan(dir, 0)
        assert.equals(1, #files)
        assert.equals("test.code-workspace", vim.fn.fnamemodify(files[1], ":t"))
    end)

    it("scans parent directory when scan_depth is 1 and nothing found in cwd", function()
        local parent = vim.fn.tempname()
        vim.fn.mkdir(parent, "p")
        local child = parent .. "/subdir"
        vim.fn.mkdir(child, "p")
        local ws_path = parent .. "/parent.code-workspace"
        io.open(ws_path, "w"):close()

        local files = detector._scan(child, 1)
        assert.equals(1, #files)
        assert.equals("parent.code-workspace", vim.fn.fnamemodify(files[1], ":t"))
    end)

    it("does not scan parent when scan_depth is 0", function()
        local parent = vim.fn.tempname()
        vim.fn.mkdir(parent, "p")
        local child = parent .. "/subdir"
        vim.fn.mkdir(child, "p")
        io.open(parent .. "/parent.code-workspace", "w"):close()

        local files = detector._scan(child, 0)
        assert.same({}, files)
    end)

    it("returns multiple files when several exist in the same directory", function()
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        io.open(dir .. "/a.code-workspace", "w"):close()
        io.open(dir .. "/b.code-workspace", "w"):close()
        local files = detector._scan(dir, 0)
        assert.equals(2, #files)
    end)
end)

describe("detector._scan_recursive", function()
    before_each(function()
        load_calls = {}
        package.loaded["code-workspace.detector"] = nil
        detector = require("code-workspace.detector")
    end)

    it("finds a .code-workspace file nested in a subdirectory", function()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root .. "/.git", "p")
        vim.fn.mkdir(root .. "/apps", "p")
        io.open(root .. "/apps/Apps.code-workspace", "w"):close()

        local files = detector._scan_recursive(root)
        assert.equals(1, #files)
        assert.equals("Apps.code-workspace", vim.fn.fnamemodify(files[1], ":t"))
    end)

    it("finds files nested several directories deep", function()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root .. "/.git", "p")
        vim.fn.mkdir(root .. "/a/b/c", "p")
        io.open(root .. "/a/b/c/deep.code-workspace", "w"):close()

        local files = detector._scan_recursive(root)
        assert.equals(1, #files)
    end)

    it("returns empty table when nothing found anywhere under the project root", function()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root .. "/.git", "p")
        vim.fn.mkdir(root .. "/apps", "p")

        local files = detector._scan_recursive(root)
        assert.same({}, files)
    end)

    it("falls back to the given directory when no .git root is found", function()
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        io.open(dir .. "/standalone.code-workspace", "w"):close()

        local files = detector._scan_recursive(dir)
        assert.equals(1, #files)
    end)

    it("finds multiple nested files across different subdirectories", function()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root .. "/.git", "p")
        vim.fn.mkdir(root .. "/apps", "p")
        vim.fn.mkdir(root .. "/tools", "p")
        io.open(root .. "/apps/Apps.code-workspace", "w"):close()
        io.open(root .. "/tools/Tools.code-workspace", "w"):close()

        local files = detector._scan_recursive(root)
        assert.equals(2, #files)
    end)
end)

describe(":Workspace show", function()
    local explorer_calls
    local active_workspace

    before_each(function()
        explorer_calls = {}
        active_workspace = nil

        package.loaded["code-workspace.loader"] = {
            load = function(ws) active_workspace = ws end,
            close = function() end,
            active = function() return active_workspace end,
        }
        package.loaded["code-workspace"] = {
            explorer = function() table.insert(explorer_calls, true) end,
        }
        package.loaded["code-workspace.detector"] = nil
        detector = require("code-workspace.detector")
        detector.setup({ scan_depth = 1 })
    end)

    after_each(function()
        pcall(vim.api.nvim_del_user_command, "Workspace")
        package.loaded["code-workspace"] = nil
        package.loaded["code-workspace.loader"] = nil
        package.loaded["code-workspace.detector"] = nil
    end)

    it("calls code-workspace.explorer() when a workspace is active", function()
        active_workspace = { name = "test", folders = {} }
        vim.cmd("Workspace show")
        assert.equals(1, #explorer_calls)
    end)

    it("warns and does not call explorer() when no workspace is active", function()
        local notified = {}
        local orig_notify = vim.notify
        vim.notify = function(msg, level) table.insert(notified, { msg = msg, level = level }) end

        vim.cmd("Workspace show")

        vim.notify = orig_notify
        assert.equals(0, #explorer_calls)
        assert.equals(1, #notified)
        assert.equals(vim.log.levels.WARN, notified[1].level)
    end)
end)
