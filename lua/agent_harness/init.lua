local M = {}

local defaults = {
  default_agent = "codex",
  split_size = "40%",
  paste_delay_ms = 400,
  startup_timeout_ms = 5000,
  startup_poll_ms = 100,
  pane_picker_window_style = "fg=colour16,bg=colour226,bold",
  pane_picker_window_format = ">>> #I:#W <<<",
  pane_preview_lines = 20,
  agents = {
    claude = {
      label = "Claude Code",
      command = "claude",
      initial_prompt_arg = true,
    },
    codex = {
      label = "Codex",
      command = "codex",
      initial_prompt_arg = true,
    },
    opencode = {
      label = "OpenCode",
      command = "opencode",
    },
    pi = {
      label = "Pi",
      command = "pi",
      variants = {
        read = {
          label = "Pi (read only)",
          args = { "--tools", "read,grep,find,ls" },
          allow_unknown_variant_panes = true,
        },
      },
    },
  },
}

local state = {
  current_agent = nil,
  pane_by_agent = {},
  did_setup = false,
}

M.options = vim.deepcopy(defaults)

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Agent Harness" })
end

local function trim(value)
  return vim.trim(value or "")
end

local function system(args, input)
  local output
  if input ~= nil then
    output = vim.fn.system(args, input)
  else
    output = vim.fn.system(args)
  end

  return vim.v.shell_error == 0, trim(output), vim.v.shell_error
end

local function agent_variants(agent)
  return agent.variants or agent.configs
end

local function merge_agent_variant(name, base_name, base_agent, variant_name, variant)
  local agent = vim.tbl_deep_extend("force", vim.deepcopy(base_agent), variant or {})
  agent.variants = nil
  agent.configs = nil
  agent.profile_name = name
  agent.base_name = base_name
  agent.variant_name = variant_name

  if variant_name and not agent.label then
    agent.label = (base_agent.label or base_name) .. " (" .. variant_name .. ")"
  end

  return agent
end

local function resolve_agent_config(name)
  if not name then
    return nil, nil
  end

  local agent = M.options.agents[name]
  if agent then
    return name, merge_agent_variant(name, name, agent)
  end

  local base_name, variant_name = name:match("^([^:]+):(.+)$")
  local base_agent = base_name and M.options.agents[base_name]
  local variants = base_agent and agent_variants(base_agent)
  local variant = variants and variants[variant_name]
  if not variant then
    return nil, nil
  end

  return name, merge_agent_variant(name, base_name, base_agent, variant_name, variant)
end

local function agent_names()
  local names = {}
  for name, agent in pairs(M.options.agents) do
    table.insert(names, name)

    local variants = agent_variants(agent)
    if variants then
      for variant_name, _ in pairs(variants) do
        table.insert(names, name .. ":" .. variant_name)
      end
    end
  end
  table.sort(names)
  return names
end

local function normalize_agent_arg(arg)
  arg = trim(arg)
  if arg == "" then
    return nil
  end
  return arg
end

local function ensure_current_agent()
  if state.current_agent and resolve_agent_config(state.current_agent) then
    return state.current_agent
  end

  if resolve_agent_config(M.options.default_agent) then
    state.current_agent = M.options.default_agent
    return state.current_agent
  end

  local names = agent_names()
  state.current_agent = names[1]
  return state.current_agent
end

local function resolve_agent(name)
  name = name or ensure_current_agent()
  if not name then
    notify("No agent harnesses are configured", vim.log.levels.ERROR)
    return nil, nil
  end

  local requested_name = name
  local agent
  name, agent = resolve_agent_config(name)
  if not agent then
    notify("Unknown agent harness: " .. requested_name, vim.log.levels.ERROR)
    return nil, nil
  end

  state.current_agent = name
  return name, agent
end

local function project_root(bufnr)
  local ok, util = pcall(require, "config.util")
  if ok and util.project_root then
    return util.project_root(bufnr)
  end

  return vim.uv.cwd()
end

local function relative_path(path, cwd)
  if path == "" then
    return "[No Name]"
  end

  local rel = vim.fs.relpath(cwd, path)
  if rel then
    return rel
  end

  return vim.fn.fnamemodify(path, ":~")
end

local function get_lines(bufnr, start_line, end_line)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  start_line = math.max(1, math.min(start_line, line_count))
  end_line = math.max(1, math.min(end_line, line_count))

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  return start_line, end_line, vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
end

local function code_block(filetype, lines)
  local max_ticks = 2
  for _, line in ipairs(lines) do
    for ticks in line:gmatch("`+") do
      max_ticks = math.max(max_ticks, #ticks)
    end
  end

  local fence = string.rep("`", math.max(3, max_ticks + 1))
  local lang = filetype ~= "" and filetype or "text"
  return fence .. lang .. "\n" .. table.concat(lines, "\n") .. "\n" .. fence
end

local function collect_context(opts)
  opts = opts or {}
  if opts.no_context or opts.context == false then
    return nil
  end

  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local win = opts.win or vim.api.nvim_get_current_win()
  local cwd = project_root(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local display_path = relative_path(path, cwd)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local filetype = vim.bo[bufnr].filetype

  local parts = {
    "- cwd: " .. cwd,
    "- cursor: line " .. cursor[1] .. ", column " .. (cursor[2] + 1),
  }

  if vim.bo[bufnr].modified then
    table.insert(parts, "- note: this buffer has unsaved changes")
  end

  if opts.has_range then
    local start_line, end_line, lines = get_lines(bufnr, opts.line1, opts.line2)
    table.insert(parts, "Selected lines in " .. display_path .. ":" .. start_line .. "-" .. end_line)
    table.insert(parts, code_block(filetype, lines))

    return {
      kind = "selection",
      label = display_path .. ":" .. start_line .. "-" .. end_line,
      text = table.concat(parts, "\n"),
    }
  elseif opts.include_buffer then
    local _, _, lines = get_lines(bufnr, 1, vim.api.nvim_buf_line_count(bufnr))
    table.insert(parts, "- included buffer: " .. display_path)
    table.insert(parts, "")
    table.insert(parts, "Current buffer:")
    table.insert(parts, code_block(filetype, lines))

    return {
      kind = "buffer",
      label = display_path .. " contents",
      text = table.concat(parts, "\n"),
    }
  else
    table.insert(parts, "- current file: " .. display_path)
    table.insert(parts, "")

    return {
      kind = "file",
      label = display_path,
      text = table.concat(parts, "\n"),
    }
  end
end

local function context_text(context)
  if type(context) == "table" then
    return trim(context.text)
  end

  if type(context) == "string" then
    return trim(context)
  end

  return ""
end

local function build_prompt(instructions, context)
  local parts = {}
  local text = context_text(context)
  if text ~= "" then
    table.insert(parts, text)
    table.insert(parts, "")
  end

  vim.list_extend(parts, {
    trim(instructions),
  })

  return table.concat(parts, "\n")
end

local function tmux_ready()
  if vim.fn.executable("tmux") ~= 1 then
    notify("tmux executable was not found", vim.log.levels.ERROR)
    return false
  end

  if not vim.env.TMUX_PANE then
    notify("Start Neovim inside tmux to use Agent Harness", vim.log.levels.ERROR)
    return false
  end

  return true
end

local function pane_alive(pane)
  if not pane or pane == "" or not vim.env.TMUX_PANE then
    return false
  end

  local ok = system({ "tmux", "display-message", "-p", "-t", pane, "#{pane_id}" })
  return ok
end

local function command_name(command)
  command = trim(command)
  local first = command:match("^%s*([^%s]+)")
  if not first then
    return ""
  end

  first = first:gsub("^['\"]", ""):gsub("['\"]$", "")
  return vim.fn.fnamemodify(first, ":t")
end

local function agent_command_args(agent)
  local args = {}

  if type(agent.command) == "table" then
    for _, arg in ipairs(agent.command) do
      table.insert(args, tostring(arg))
    end
  elseif type(agent.command) == "string" and agent.command ~= "" then
    table.insert(args, agent.command)
  end

  if type(agent.args) == "table" then
    for _, arg in ipairs(agent.args) do
      table.insert(args, tostring(arg))
    end
  end

  return args
end

local function agent_command_display(agent)
  return table.concat(agent_command_args(agent), " ")
end

local function agent_executable(agent)
  local args = agent_command_args(agent)
  return args[1] or ""
end

local function agent_required_process_terms(agent)
  local terms = {}

  local function add(term)
    term = trim(term)
    if term ~= "" then
      table.insert(terms, term)
    end
  end

  if type(agent.process_terms) == "table" then
    for _, term in ipairs(agent.process_terms) do
      add(term)
    end
  end

  if type(agent.command) == "table" then
    for index = 2, #agent.command do
      add(agent.command[index])
    end
  end

  if type(agent.args) == "table" then
    for _, arg in ipairs(agent.args) do
      add(arg)
    end
  end

  return terms
end

local function agent_process_names(agent)
  local names = {}
  local seen = {}

  local function add(name)
    name = command_name(name)
    if name ~= "" and not seen[name] then
      seen[name] = true
      table.insert(names, name)
    end
  end

  if type(agent.process_names) == "table" then
    for _, name in ipairs(agent.process_names) do
      add(name)
    end
  end

  if type(agent.process_name) == "string" then
    add(agent.process_name)
  end

  add(agent_executable(agent))
  return names
end

local function tag_pane(agent_name, pane)
  if not pane or pane == "" then
    return
  end

  system({ "tmux", "set-option", "-p", "-q", "-t", pane, "@agent-harness", agent_name })
end

local function list_panes()
  if vim.fn.executable("tmux") ~= 1 or not vim.env.TMUX_PANE then
    return {}
  end

  local sep = "\31"
  local fields = {
    "#{pane_id}",
    "#{window_id}",
    "#{session_name}",
    "#{window_index}",
    "#{pane_index}",
    "#{window_name}",
    "#{pane_current_command}",
    "#{pane_current_path}",
    "#{pane_start_command}",
    "#{pane_title}",
    "#{pane_tty}",
    "#{pane_active}",
    "#{pane_marked}",
    "#{@agent-harness}",
  }

  local ok, output = system({ "tmux", "list-panes", "-a", "-F", table.concat(fields, sep) })
  if not ok or output == "" then
    return {}
  end

  local panes = {}
  for line in output:gmatch("[^\n]+") do
    local parts = vim.split(line, sep, { plain = true, trimempty = false })
    local pane = {
      id = parts[1] or "",
      window_id = parts[2] or "",
      session = parts[3] or "",
      window_index = parts[4] or "",
      pane_index = parts[5] or "",
      window_name = parts[6] or "",
      current_command = parts[7] or "",
      current_path = parts[8] or "",
      start_command = parts[9] or "",
      title = parts[10] or "",
      tty = parts[11] or "",
      active = parts[12] == "1",
      marked = parts[13] == "1",
      agent_name = parts[14] or "",
    }
    pane.location = pane.session .. ":" .. pane.window_index .. "." .. pane.pane_index

    if pane.id ~= "" then
      table.insert(panes, pane)
    end
  end

  return panes
end

local function pane_process_output(pane)
  if not pane.tty or pane.tty == "" then
    return ""
  end

  local tty = pane.tty:gsub("^/dev/", "")
  local ok, output = system({ "ps", "-t", tty, "-o", "command=" })
  if not ok then
    return ""
  end

  return output
end

local function escape_pattern(value)
  return value:gsub("([^%w])", "%%%1")
end

local function process_output_has_name(output, name)
  name = escape_pattern(name:lower())
  local pattern = "[^%w._%-]" .. name .. "[^%w._%-]"

  for line in output:gmatch("[^\n]+") do
    if ("\n" .. line:lower() .. "\n"):find(pattern) then
      return true
    end
  end

  return false
end

local function pane_process_match_kind(pane, agent)
  local output = pane_process_output(pane):lower()
  if output == "" then
    return nil
  end

  local matched_process = false
  for _, name in ipairs(agent_process_names(agent)) do
    name = name:lower()
    if name ~= "" and process_output_has_name(output, name) then
      matched_process = true
      break
    end
  end

  if not matched_process then
    return nil
  end

  local missing_required_term = false
  for _, term in ipairs(agent_required_process_terms(agent)) do
    term = term:lower()
    if term ~= "" and not output:find(term, 1, true) then
      missing_required_term = true
      break
    end
  end

  if not missing_required_term then
    return "exact"
  end

  if agent.allow_unknown_variant_panes then
    return "possible"
  end

  return nil
end

local shell_commands = {
  bash = true,
  fish = true,
  sh = true,
  zsh = true,
}

local function pane_agent_match_kind(pane, agent_name, agent)
  if pane.agent_name ~= "" then
    if pane.agent_name == agent_name and not shell_commands[command_name(pane.current_command)] then
      return "exact"
    end

    return nil
  end

  local current_command = command_name(pane.current_command)
  local start_command = command_name(pane.start_command)
  if #agent_required_process_terms(agent) == 0 then
    for _, name in ipairs(agent_process_names(agent)) do
      if current_command == name or start_command == name then
        return "exact"
      end
    end
  end

  local process_match_kind = pane_process_match_kind(pane, agent)
  if process_match_kind then
    return process_match_kind
  end

  return nil
end

local function find_pane(pane_id)
  if not pane_id or pane_id == "" then
    return nil
  end

  for _, pane in ipairs(list_panes()) do
    if pane.id == pane_id then
      return pane
    end
  end

  return nil
end

local function current_window_id()
  local pane = find_pane(vim.env.TMUX_PANE)
  return pane and pane.window_id or nil
end

local function pane_in_current_window(pane)
  local window = current_window_id()
  return not window or pane.window_id == window
end

local function find_agent_panes(agent_name, agent)
  local panes = {}
  for _, pane in ipairs(list_panes()) do
    local match_kind = pane_agent_match_kind(pane, agent_name, agent)
    if match_kind then
      pane.agent_match_kind = match_kind
      table.insert(panes, pane)
    end
  end

  return panes
end

local function marked_pane()
  for _, pane in ipairs(list_panes()) do
    if pane.marked then
      return pane.id
    end
  end

  return nil
end

local function clear_marked_pane()
  system({ "tmux", "select-pane", "-M" })
end

local function mark_pane(pane)
  if pane and pane ~= "" and pane_alive(pane) then
    system({ "tmux", "select-pane", "-m", "-t", pane })
  else
    clear_marked_pane()
  end
end

local function restore_marked_pane(pane)
  clear_marked_pane()
  if pane and pane_alive(pane) then
    mark_pane(pane)
  end
end

local function focus_pane(pane)
  local target = find_pane(pane)
  if not target then
    notify("Agent tmux pane is no longer available", vim.log.levels.ERROR)
    return false
  end

  local switched = true
  if target.window_id ~= current_window_id() then
    local ok, output = system({ "tmux", "switch-client", "-t", target.session .. ":" .. target.window_index })
    if not ok then
      notify("Failed to switch to agent tmux window: " .. output, vim.log.levels.ERROR)
      switched = false
    end
  end

  local ok, output = system({ "tmux", "select-pane", "-t", pane })
  if not ok then
    notify("Failed to focus agent tmux pane: " .. output, vim.log.levels.ERROR)
    return false
  end

  return switched
end

local window_highlight_style_options = {
  "window-status-style",
  "window-status-current-style",
}

local window_highlight_format_options = {
  "window-status-format",
  "window-status-current-format",
}

local function snapshot_window_option(window, option)
  local ok, output = system({ "tmux", "show-options", "-w", "-q", "-v", "-t", window, option })
  if not ok or output == "" then
    return { set = false }
  end

  return {
    set = true,
    value = output,
  }
end

local function restore_window_highlight(state)
  for window, options in pairs(state.snapshots or {}) do
    for option, snapshot in pairs(options) do
      if snapshot.set then
        system({ "tmux", "set-option", "-w", "-q", "-t", window, option, snapshot.value })
      else
        system({ "tmux", "set-option", "-w", "-q", "-u", "-t", window, option })
      end
    end
  end

  state.window = nil
  state.snapshots = {}
end

local function highlight_window(window, state)
  if state.window == window then
    return
  end

  restore_window_highlight(state)
  if not window or window == "" then
    return
  end

  local style = trim(M.options.pane_picker_window_style)
  local format = trim(M.options.pane_picker_window_format)
  if style == "" and format == "" then
    return
  end

  state.window = window
  state.snapshots[window] = {}

  for _, option in ipairs(window_highlight_style_options) do
    if style ~= "" then
      state.snapshots[window][option] = snapshot_window_option(window, option)
      system({ "tmux", "set-option", "-w", "-q", "-t", window, option, style })
    end
  end

  for _, option in ipairs(window_highlight_format_options) do
    if format ~= "" then
      state.snapshots[window][option] = snapshot_window_option(window, option)
      system({ "tmux", "set-option", "-w", "-q", "-t", window, option, format })
    end
  end
end

local function start_pane(agent_name, agent, initial_prompt)
  if not tmux_ready() then
    return nil
  end

  local cwd = project_root(0)
  local args = {
    "tmux",
    "split-window",
    "-h",
    "-t",
    vim.env.TMUX_PANE,
    "-P",
    "-F",
    "#{pane_id}",
    "-c",
    cwd,
  }

  if M.options.split_size and M.options.split_size ~= "" then
    table.insert(args, "-l")
    table.insert(args, tostring(M.options.split_size))
  end

  vim.list_extend(args, agent_command_args(agent))
  local prompt_sent = false
  if agent.initial_prompt_arg and trim(initial_prompt) ~= "" then
    table.insert(args, initial_prompt)
    prompt_sent = true
  end

  local ok, output = system(args)
  if not ok then
    notify("Failed to start " .. (agent.label or agent_name) .. ": " .. output, vim.log.levels.ERROR)
    return nil
  end

  local pane = output:match("%%?%d+")
  if not pane then
    notify("tmux did not return a pane id", vim.log.levels.ERROR)
    return nil
  end

  state.pane_by_agent[agent_name] = pane
  tag_pane(agent_name, pane)
  return pane, true, prompt_sent
end

local function pane_choice_label(choice)
  if choice.start_new then
    return "Start new " .. choice.label .. " pane"
  end

  local pane = choice.pane
  local path = pane.current_path ~= "" and vim.fn.fnamemodify(pane.current_path, ":~") or "-"
  local command = pane.current_command ~= "" and pane.current_command or pane.start_command
  local mode = pane.agent_match_kind == "possible" and "  [mode unknown]" or ""
  return pane.id .. "  " .. pane.location .. "  " .. command .. mode .. "  " .. path
end

local function pane_preview_lines(choice)
  if choice.start_new then
    return { "Start new " .. choice.label .. " pane" }
  end

  local pane = choice.pane
  if not pane or not pane.id then
    return { "No pane selected" }
  end

  local line_limit = tonumber(M.options.pane_preview_lines or M.options.pane_preview_history_lines) or 20
  line_limit = math.max(1, math.floor(line_limit))

  local ok, output = system({
    "tmux",
    "capture-pane",
    "-p",
    "-t",
    pane.id,
  })
  if not ok then
    return {
      "Unable to capture " .. pane.id,
      output,
    }
  end

  local captured = vim.split(output, "\n", { plain = true, trimempty = false })
  while #captured > 1 and captured[#captured] == "" do
    table.remove(captured)
  end

  local lines = {}
  local start = math.max(1, #captured - line_limit + 1)
  for index = start, #captured do
    table.insert(lines, captured[index])
  end

  while #lines > 1 and trim(lines[1]) == "" do
    table.remove(lines)
  end

  if #lines == 0 then
    lines = { "" }
  end

  local command = pane.current_command ~= "" and pane.current_command or pane.start_command
  local header = pane.id .. "  " .. pane.location .. "  " .. command
  table.insert(lines, 1, string.rep("-", math.max(20, #header)))
  table.insert(lines, 1, header)
  return lines
end

local function telescope_select_pane(choices, prompt, on_choice)
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    return false
  end

  local finders = require("telescope.finders")
  local previewers = require("telescope.previewers")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previous_mark = marked_pane()
  local window_highlight = { snapshots = {} }
  local finished = false
  local selected = false
  local last_marked = nil
  local timer = vim.uv.new_timer()

  local function stop_timer()
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
  end

  local function finish(choice)
    if finished then
      return
    end

    finished = true
    stop_timer()
    restore_window_highlight(window_highlight)
    restore_marked_pane(previous_mark)
    vim.schedule(function()
      on_choice(choice)
    end)
  end

  local function sync_mark(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)
    local entry = picker and picker:get_selection()
    local choice = entry and entry.value
    local pane = choice and choice.pane or nil
    local pane_id = pane and pane.id or nil

    if pane_id ~= last_marked then
      last_marked = pane_id
      mark_pane(pane_id)
    end

    highlight_window(pane and pane.window_id or nil, window_highlight)
  end

  pickers
    .new({}, {
      prompt_title = prompt,
      finder = finders.new_table({
        results = choices,
        entry_maker = function(choice)
          local label = pane_choice_label(choice)
          return {
            value = choice,
            display = label,
            ordinal = label,
          }
        end,
      }),
      previewer = previewers.new_buffer_previewer({
        title = "tmux pane",
        dyn_title = function(_, entry)
          local choice = entry and entry.value
          if not choice or choice.start_new then
            return "new pane"
          end

          local pane = choice.pane
          return pane.id .. " " .. pane.location
        end,
        define_preview = function(self, entry)
          if not entry or not entry.value then
            return
          end

          vim.bo[self.state.bufnr].modifiable = true
          vim.bo[self.state.bufnr].filetype = "text"
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, pane_preview_lines(entry.value))
          vim.bo[self.state.bufnr].modifiable = false
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        timer:start(
          50,
          100,
          vim.schedule_wrap(function()
            if not finished then
              pcall(sync_mark, prompt_bufnr)
            end
          end)
        )

        actions.select_default:replace(function()
          selected = true
          local entry = action_state.get_selected_entry()
          local choice = entry and entry.value
          actions.close(prompt_bufnr)
          finish(choice)
        end)

        actions.close:enhance({
          post = function()
            if not selected then
              finish(nil)
            end
          end,
        })

        return true
      end,
    })
    :find()

  return true
end

local function select_pane(agent_name, agent, panes, on_choice)
  local choices = {}
  for _, pane in ipairs(panes) do
    table.insert(choices, {
      pane = pane,
      label = agent.label or agent_name,
    })
  end

  table.insert(choices, {
    start_new = true,
    label = agent.label or agent_name,
  })

  local prompt = "Select " .. (agent.label or agent_name) .. " pane"
  if telescope_select_pane(choices, prompt, on_choice) then
    return
  end

  local previous_mark = marked_pane()
  vim.ui.select(choices, {
    prompt = prompt,
    format_item = pane_choice_label,
  }, function(choice)
    restore_marked_pane(previous_mark)
    on_choice(choice)
  end)
end

local function get_or_start_pane(agent_name, agent, force, on_pane, start_prompt)
  on_pane = on_pane or function() end

  if not tmux_ready() then
    on_pane(nil)
    return
  end

  local pane = state.pane_by_agent[agent_name]
  local remembered_pane = find_pane(pane)
  local remembered_match_kind = remembered_pane and pane_agent_match_kind(remembered_pane, agent_name, agent)
  if
    not force
    and remembered_pane
    and remembered_match_kind == "exact"
    and pane_in_current_window(remembered_pane)
  then
    on_pane(remembered_pane.id, false)
    return
  end

  if pane then
    state.pane_by_agent[agent_name] = nil
  end

  if force then
    on_pane(start_pane(agent_name, agent, start_prompt))
    return
  end

  local panes = find_agent_panes(agent_name, agent)
  local function use_choice(choice)
    if not choice then
      on_pane(nil)
      return
    end

    if choice.start_new then
      on_pane(start_pane(agent_name, agent, start_prompt))
      return
    end

    local selected_pane = choice.pane and choice.pane.id
    if pane_alive(selected_pane) then
      state.pane_by_agent[agent_name] = selected_pane
      tag_pane(agent_name, selected_pane)
      on_pane(selected_pane, false)
    else
      state.pane_by_agent[agent_name] = nil
      notify("Selected tmux pane is no longer available", vim.log.levels.WARN)
      get_or_start_pane(agent_name, agent, false, on_pane)
    end
  end

  if #panes == 1 then
    if panes[1].agent_match_kind == "exact" and pane_in_current_window(panes[1]) then
      state.pane_by_agent[agent_name] = panes[1].id
      tag_pane(agent_name, panes[1].id)
      on_pane(panes[1].id, false)
      return
    end

    select_pane(agent_name, agent, panes, use_choice)
    return
  end

  if #panes > 1 then
    select_pane(agent_name, agent, panes, use_choice)
    return
  end

  on_pane(start_pane(agent_name, agent, start_prompt))
end

local function pane_target_error(output)
  output = output or ""
  return output:match("can't find pane") or output:match("no such pane") or output:match("pane not found")
end

local function pane_has_visible_content(pane)
  local ok, output = system({ "tmux", "capture-pane", "-p", "-t", pane })
  return ok and trim(output) ~= ""
end

local function pane_is_agent_process(pane, agent)
  local ok, output = system({ "tmux", "display-message", "-p", "-t", pane, "#{pane_current_command}" })
  if not ok then
    return false
  end

  local current_command = command_name(output)
  for _, process_name in ipairs(agent_process_names(agent)) do
    if current_command == process_name then
      return true
    end
  end

  return false
end

local function wait_for_new_pane(pane, agent, on_ready, on_missing)
  local timeout = tonumber(M.options.startup_timeout_ms) or 5000
  local poll = tonumber(M.options.startup_poll_ms) or 100
  timeout = math.max(0, timeout)
  poll = math.max(25, poll)

  local started_at = vim.uv.now()
  local timer = vim.uv.new_timer()
  if not timer then
    on_ready()
    return
  end

  local function finish(callback)
    timer:stop()
    timer:close()
    vim.schedule(callback)
  end

  timer:start(
    0,
    poll,
    vim.schedule_wrap(function()
      if not pane_alive(pane) then
        finish(function()
          if on_missing then
            on_missing()
          end
        end)
        return
      end

      if pane_is_agent_process(pane, agent) and pane_has_visible_content(pane) then
        finish(on_ready)
        return
      end

      if vim.uv.now() - started_at >= timeout then
        finish(on_ready)
      end
    end)
  )
end

local function paste_to_pane(pane, text, agent, new_pane, submit, on_done, on_missing)
  local buffer_name = "nvim-agent-" .. tostring(vim.uv.hrtime())
  local ok, output = system({ "tmux", "load-buffer", "-b", buffer_name, "-" }, text)
  if not ok then
    notify("Failed to prepare tmux paste buffer: " .. output, vim.log.levels.ERROR)
    return
  end

  local function paste()
    if not pane_alive(pane) then
      system({ "tmux", "delete-buffer", "-b", buffer_name })
      if on_missing then
        on_missing()
      else
        notify("Agent tmux pane is no longer available", vim.log.levels.ERROR)
      end
      return
    end

    local paste_ok, paste_output = system({
      "tmux",
      "paste-buffer",
      "-d",
      "-p",
      "-r",
      "-b",
      buffer_name,
      "-t",
      pane,
    })
    if not paste_ok then
      system({ "tmux", "delete-buffer", "-b", buffer_name })
      if pane_target_error(paste_output) and on_missing then
        on_missing()
        return
      end

      notify("Failed to paste prompt into tmux pane: " .. paste_output, vim.log.levels.ERROR)
      return
    end

    if submit then
      local enter_ok, enter_output = system({ "tmux", "send-keys", "-t", pane, "Enter" })
      if not enter_ok then
        if pane_target_error(enter_output) and on_missing then
          on_missing()
          return
        end

        notify("Pasted prompt, but failed to press Enter: " .. enter_output, vim.log.levels.WARN)
        return
      end
    end

    if on_done then
      on_done()
    end
  end

  local function defer_paste()
    vim.defer_fn(paste, M.options.paste_delay_ms)
  end

  if new_pane then
    wait_for_new_pane(pane, agent, defer_paste, function()
      system({ "tmux", "delete-buffer", "-b", buffer_name })
      if on_missing then
        on_missing()
      end
    end)
    return
  end

  defer_paste()
end

function M.select(callback)
  local choices = {}
  for _, name in ipairs(agent_names()) do
    local _, agent = resolve_agent_config(name)
    table.insert(choices, {
      name = name,
      agent = agent,
      label = agent.label or name,
      command = agent_command_display(agent),
    })
  end

  vim.ui.select(choices, {
    prompt = "Agent harness",
    format_item = function(item)
      return item.label .. " (" .. item.command .. ")"
    end,
  }, function(choice)
    if not choice then
      return
    end

    state.current_agent = choice.name
    notify("Selected " .. choice.label)

    if callback then
      callback(choice.name, choice.agent)
    end
  end)
end

function M.start(opts)
  opts = opts or {}

  local agent_name, agent = resolve_agent(opts.agent)
  if not agent_name then
    return
  end

  get_or_start_pane(agent_name, agent, opts.force, function(pane)
    if pane then
      if opts.focus then
        focus_pane(pane)
      end
      notify((agent.label or agent_name) .. " ready in tmux pane " .. pane)
    end
  end)
end

function M.send(opts)
  opts = opts or {}

  local agent_name, agent = resolve_agent(opts.agent)
  if not agent_name then
    return
  end

  local context = opts.context
  if context == nil and not opts.no_context then
    context = collect_context(opts)
  end

  local prompt = opts.prompt or build_prompt(opts.instructions or "", context)
  local retried = false

  local function send_to_pane(pane, new_pane, prompt_sent)
    if not pane then
      return
    end

    if prompt_sent then
      notify("Sent prompt to " .. (agent.label or agent_name))
      return
    end

    paste_to_pane(pane, prompt, agent, new_pane, true, function()
      notify("Sent prompt to " .. (agent.label or agent_name))
    end, function()
      if retried then
        notify("Agent tmux pane is no longer available", vim.log.levels.ERROR)
        return
      end

      retried = true
      state.pane_by_agent[agent_name] = nil
      get_or_start_pane(agent_name, agent, false, send_to_pane)
    end)
  end

  get_or_start_pane(agent_name, agent, opts.force, send_to_pane, prompt)
end

function M.send_context(opts)
  opts = opts or {}

  local agent_name, agent = resolve_agent(opts.agent)
  if not agent_name then
    return
  end

  local context = opts.context
  if context == nil then
    context = collect_context(opts)
  end

  local prompt = context_text(context)
  if prompt == "" then
    notify("No agent context to send", vim.log.levels.WARN)
    return
  end

  prompt = prompt .. "\n"
  local retried = false

  local function stage_in_pane(pane, new_pane)
    if not pane then
      return
    end

    paste_to_pane(pane, prompt, agent, new_pane, false, function()
      focus_pane(pane)
      notify("Staged context for " .. (agent.label or agent_name))
    end, function()
      if retried then
        notify("Agent tmux pane is no longer available", vim.log.levels.ERROR)
        return
      end

      retried = true
      state.pane_by_agent[agent_name] = nil
      get_or_start_pane(agent_name, agent, false, stage_in_pane)
    end)
  end

  get_or_start_pane(agent_name, agent, opts.force, stage_in_pane)
end

function M.switch(opts)
  opts = opts or {}

  local agent_name, agent = resolve_agent(opts.agent)
  if not agent_name then
    return
  end

  get_or_start_pane(agent_name, agent, opts.force, function(pane)
    if pane and focus_pane(pane) then
      notify("Switched to " .. (agent.label or agent_name))
    end
  end)
end

local function create_commands()
  vim.api.nvim_create_user_command("AgentSelect", function()
    M.select()
  end, {
    desc = "Select the default terminal agent harness",
    force = true,
  })

  vim.api.nvim_create_user_command("AgentStart", function(args)
    M.start({
      agent = normalize_agent_arg(args.args),
      force = args.bang,
    })
  end, {
    bang = true,
    complete = agent_names,
    desc = "Start the selected terminal agent harness in tmux",
    force = true,
    nargs = "?",
  })

  vim.api.nvim_create_user_command("AgentSendContext", function(args)
    M.send_context({
      agent = normalize_agent_arg(args.args),
      has_range = args.range > 0,
      include_buffer = args.bang,
      line1 = args.line1,
      line2 = args.line2,
    })
  end, {
    bang = true,
    complete = agent_names,
    desc = "Stage file context in the selected terminal agent harness",
    force = true,
    nargs = "?",
    range = true,
  })

  vim.api.nvim_create_user_command("AgentSwitch", function(args)
    M.switch({
      agent = normalize_agent_arg(args.args),
      force = args.bang,
    })
  end, {
    bang = true,
    complete = agent_names,
    desc = "Switch to the selected terminal agent harness without sending context",
    force = true,
    nargs = "?",
  })

  vim.api.nvim_create_user_command("AgentAsk", function(args)
    M.send_context({
      agent = normalize_agent_arg(args.args),
      has_range = args.range > 0,
      include_buffer = args.bang,
      line1 = args.line1,
      line2 = args.line2,
    })
  end, {
    bang = true,
    complete = agent_names,
    desc = "Alias for AgentSendContext",
    force = true,
    nargs = "?",
    range = true,
  })

  vim.api.nvim_create_user_command("AgentAskNoContext", function(args)
    M.switch({
      agent = normalize_agent_arg(args.args),
      force = args.bang,
    })
  end, {
    bang = true,
    complete = agent_names,
    desc = "Alias for AgentSwitch",
    force = true,
    nargs = "?",
  })
end

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  ensure_current_agent()

  if not state.did_setup then
    create_commands()
    state.did_setup = true
  end
end

return M
