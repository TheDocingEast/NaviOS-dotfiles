return {
  {
    "3rd/image.nvim",
    -- If you are using luarocks for magick rock:
    dependencies = { "vhyrro/luarocks.nvim" },
    config = function()
      -- If you installed magick via luarocks, ensure the path is correct
      -- (only needed if you use luarocks.nvim)
      require("image").setup({
        backend = "kitty", -- or "ueberzug" or "sixel"
        processor = "magick_cli", -- using CLI ImageMagick
        integrations = {
          markdown = {
            enabled = true,
            clear_in_insert_mode = false,
            download_remote_images = true,
            only_render_image_at_cursor = false,
            only_render_image_at_cursor_mode = "popup",
            floating_windows = false,
            filetypes = { "markdown", "vimwiki" },
          },
          neorg = {
            enabled = true,
            filetypes = { "norg" },
          },
          -- add more integrations here if needed
        },
        max_width = nil,
        max_height = nil,
        max_width_window_percentage = nil,
        max_height_window_percentage = 50,
        scale_factor = 1.0,
        window_overlap_clear_enabled = false,
        window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs" },
        editor_only_render_when_focused = false,
        tmux_show_only_in_active_window = false,
        hijack_file_patterns = {
          "*.png",
          "*.jpg",
          "*.jpeg",
          "*.gif",
          "*.webp",
          "*.svg",
          "*.avif",
        },
      })

      -- Optional command / keymap
      vim.keymap.set("n", "<leader>ir", function()
        if require("image").is_enabled() then
          require("image").disable()
        else
          require("image").enable()
        end
      end, { desc = "Toggle Image Preview" })
    end,
  },
}
