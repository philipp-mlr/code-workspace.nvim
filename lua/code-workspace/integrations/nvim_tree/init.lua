-- nvim-tree.lua integration.
--
-- Unlike snacks.explorer (a picker source that can render N roots in one
-- session), nvim-tree's core is single-root: `nvim-tree.api.tree.open({path=...})`
-- and `change_root(path)` both destroy and recreate one Explorer for one path
-- (see nvim-tree.core.init). There is no multi-root tree view to integrate
-- with.
--
-- So instead of a multi-root tree, this opens a single nvim-tree rooted at
-- the workspace's first folder, and adds a buffer-local keymap inside the
-- tree window to switch its root between the workspace's folders via
-- vim.ui.select. This keeps nvim-tree as the file tree backend (no
-- dependency on snacks.explorer) while still giving quick access to every
-- workspace root.

local M = {}

--- Root-switch key set for the current workspace's tree buffer.
---@param workspace code_workspace.Workspace
---@param bufnr integer
local function set_switch_root_keymap(workspace, bufnr)
    vim.keymap.set("n", "<leader>cw", function()
        local folders = workspace.folders
        vim.ui.select(folders, {
            prompt = "Switch workspace root",
            format_item = function(folder)
                return folder.name
            end,
        }, function(choice)
            if choice then
                require("nvim-tree.api").tree.change_root(choice.path)
            end
        end)
    end, {
        buffer = bufnr,
        silent = true,
        desc = "code-workspace: switch tree root",
    })
end

--- Open (or focus) nvim-tree rooted at the workspace's first folder, and wire
--- up the root-switch keymap for as long as this workspace stays active.
---@param workspace code_workspace.Workspace
function M.open(workspace)
    if not workspace or not workspace.folders or #workspace.folders == 0 then
        return
    end

    local ok, api = pcall(require, "nvim-tree.api")
    if not ok then
        vim.notify("[code-workspace] nvim-tree.lua is not installed", vim.log.levels.ERROR)
        return
    end

    local root = workspace.folders[1].path

    -- api.tree.open({path=...}) only applies `path` while initialising a
    -- fresh Explorer (nvim-tree.lib.open: `if not core.get_explorer() or
    -- opts.path`) or while the tree window is closed. If the tree is
    -- already open, open() just focuses the existing window and silently
    -- ignores `path` -- so re-opening a workspace with nvim-tree already
    -- visible left the tree rooted wherever it was before. Explicitly
    -- change_root after open()/focus() so the root always follows the
    -- workspace regardless of the tree's prior state.
    api.tree.open({ path = root })
    api.tree.change_root(root)

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "NvimTree",
        group = vim.api.nvim_create_augroup("code_workspace_nvim_tree", { clear = true }),
        callback = function(ev)
            set_switch_root_keymap(workspace, ev.buf)
        end,
    })
end

function M.setup()
    vim.api.nvim_create_autocmd("User", {
        pattern = "WorkspaceClosed",
        callback = function()
            pcall(vim.api.nvim_del_augroup_by_name, "code_workspace_nvim_tree")
            local ok, api = pcall(require, "nvim-tree.api")
            if ok then
                api.tree.change_root(vim.fn.getcwd())
            end
        end,
    })
end

return M
