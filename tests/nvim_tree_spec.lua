local function fire(pattern, data)
    vim.api.nvim_exec_autocmds("User", { pattern = pattern, data = data })
end

describe("integrations/nvim_tree/init", function()
    local integration
    local open_calls
    local change_root_calls

    before_each(function()
        package.loaded["code-workspace.integrations.nvim_tree"] = nil
        package.loaded["nvim-tree.api"] = nil

        open_calls        = {}
        change_root_calls = {}

        package.loaded["nvim-tree.api"] = {
            tree = {
                open = function(opts)
                    table.insert(open_calls, opts)
                end,
                change_root = function(path)
                    table.insert(change_root_calls, path)
                end,
            },
        }

        integration = require("code-workspace.integrations.nvim_tree")
        integration.setup()
    end)

    after_each(function()
        package.loaded["nvim-tree.api"] = nil
        package.loaded["code-workspace.integrations.nvim_tree"] = nil
        pcall(vim.api.nvim_del_augroup_by_name, "code_workspace_nvim_tree")
        vim.api.nvim_clear_autocmds({ event = "User", pattern = "WorkspaceClosed" })
        vim.api.nvim_clear_autocmds({ event = "FileType", pattern = "NvimTree" })
    end)

    describe("open()", function()
        it("opens nvim-tree rooted at the workspace's first folder", function()
            integration.open({
                folders = {
                    { name = "app", path = "/srv/app" },
                    { name = "lib", path = "/srv/lib" },
                },
            })

            assert.equals(1, #open_calls)
            assert.equals("/srv/app", open_calls[1].path)
        end)

        it("explicitly changes root to the first folder after open()", function()
            -- api.tree.open({path=...}) is a no-op re path when the tree is
            -- already visible (nvim-tree just focuses it) -- open() must be
            -- followed by an explicit change_root so re-opening a workspace
            -- always re-roots regardless of the tree's prior state.
            integration.open({
                folders = {
                    { name = "app", path = "/srv/app" },
                    { name = "lib", path = "/srv/lib" },
                },
            })

            assert.equals(1, #change_root_calls)
            assert.equals("/srv/app", change_root_calls[1])
        end)

        it("does nothing when folders list is empty", function()
            integration.open({ folders = {} })
            assert.equals(0, #open_calls)
            assert.equals(0, #change_root_calls)
        end)

        it("does nothing when workspace is nil", function()
            integration.open(nil)
            assert.equals(0, #open_calls)
            assert.equals(0, #change_root_calls)
        end)

        it("wires a root-switch keymap on the next NvimTree buffer", function()
            integration.open({ folders = { { name = "app", path = "/srv/app" } } })

            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].filetype = "NvimTree"
            vim.api.nvim_set_current_buf(buf)

            local mapping = vim.fn.maparg("<leader>cw", "n", false, true)
            assert.is_not_nil(mapping.callback)
        end)
    end)

    describe("WorkspaceClosed", function()
        it("changes nvim-tree root back to cwd", function()
            local cwd = vim.fn.getcwd()
            fire("WorkspaceClosed", { file = "/tmp/test.code-workspace" })

            assert.equals(1, #change_root_calls)
            assert.equals(cwd, change_root_calls[1])
        end)
    end)
end)
