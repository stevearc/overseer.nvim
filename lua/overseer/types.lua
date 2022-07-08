---@class overseer.Config
---@field strategy? string
---@field templates? string[]
---@field auto_detect_success_color? boolean
---@field task_list? overseer.ConfigTaskList
---@field actions? any TODO
---@field form? overseer.ConfigFloatWin
---@field confirm? overseer.ConfigFloatWin
---@field task_win? overseer.ConfigTaskWin
---@field component_aliases? table<string, overseer.Serialized[]>
---@field preload_components? string[]
---@field log table[]

---@class overseer.ConfigTaskList
---@field default_detail? 1|2|3
---@field max_width? number|number[]
---@field min_width? number|number[]
---@field separator? string
---@field direction? string
---@field bindings? table<string, string>

---@class overseer.ConfigFloatWin
---@field border? string|table
---@field zindex? integer
---@field min_width? number|number[]
---@field max_width? number|number[]
---@field min_height? number|number[]
---@field max_height? number|number[]
---@field win_opts? table<string, any>

---@class overseer.ConfigTaskWin
---@field border? string|table
---@field padding? integer
---@field win_opts? table<string, any>

---@alias overseer.Serialized string|table
