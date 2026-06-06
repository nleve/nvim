return {
  {
    'local/agent-harness',
    dir = vim.fn.stdpath('config'),
    lazy = false,
    config = function()
      require('agent_harness').setup()
    end,
    keys = {
      {
        '<leader>aa',
        function()
          require('agent_harness').send_context()
        end,
        desc = 'Agent stage context',
      },
      {
        '<leader>aa',
        ":'<,'>AgentSendContext<CR>",
        mode = 'x',
        desc = 'Agent stage selection',
      },
      {
        '<leader>aA',
        function()
          local agents = require('agent_harness')
          agents.select(function(name)
            agents.send_context({ agent = name })
          end)
        end,
        desc = 'Agent stage context (choose)',
      },
      { '<leader>af', '<cmd>AgentSendContext!<CR>', desc = 'Agent stage file contents' },
      { '<leader>an', '<cmd>AgentSwitch<CR>', desc = 'Agent switch' },
      { '<leader>as', '<cmd>AgentStart<CR>', desc = 'Agent start' },
      { '<leader>aS', '<cmd>AgentStart!<CR>', desc = 'Agent start new pane' },
      { '<leader>ac', '<cmd>AgentSelect<CR>', desc = 'Agent select' },
    },
  },
}
