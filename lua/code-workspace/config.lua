local M = {}

M.defaults = {
    detect_on_startup = false,
    detect_on_buf_read = true,
    scan_depth = 1,
    on_load = nil,
    on_close = nil,
    -- Which file-tree backend M.explorer() drives: "snacks" (default,
    -- renders every workspace folder as a root in one Snacks.explorer
    -- picker session) or "nvim_tree" (single nvim-tree instance rooted at
    -- the first folder, with a keymap to switch roots -- see
    -- integrations/nvim_tree for why nvim-tree can't show multiple roots
    -- at once).
    explorer = "snacks",
}

function M.resolve(user_opts)
    return vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
