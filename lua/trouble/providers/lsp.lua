local lsp = require("vim.lsp")
local util = require("trouble.util")

---@class Lsp
local M = {}

local function lsp_buf_request(buf, method, params, handler)
  lsp.buf_request(buf, method, params, function(err, m, result)
    handler(err, method == m and result or m)
  end)
end

local function lsp_buf_request_hierarchy(buf, method, item, handler)
  lsp.buf_request(buf, method, { item = item }, function(err, result)
    if err then
      return
    end
    handler(err, result)
  end)
end

local function pick_call_hierarchy_item(call_hierarchy_items)
  if not call_hierarchy_items then
    return
  end
  if #call_hierarchy_items == 1 then
    return call_hierarchy_items[1]
  end
  local items = {}
  for i, item in pairs(call_hierarchy_items) do
    local entry = item.detail or item.name
    table.insert(items, string.format("%d. %s", i, entry))
  end
  local choice = vim.fn.inputlist(items)
  if choice < 1 or choice > #items then
    return
  end
  return choice
end

local function call_hierarchy(buf, method, params, handler)
  lsp.buf_request(buf, "textDocument/prepareCallHierarchy", params, function(err, result)
    if err then
      util.error("Error when preparing call hierarchy: " .. err)
      return
    end

    local call_hierarchy_item = pick_call_hierarchy_item(result)
    if not call_hierarchy_item then
      return
    end

    lsp_buf_request_hierarchy(buf, method, call_hierarchy_item, handler)
  end)
end

-- A local function to convert callHierarchy/incomingCalls output to textDocument/references output format
-- @param incomingCallsResult table
-- @return table
local function incomingCallsResultToReferencesResult(incomingCallsResult)
  local referencesResult = {}
  for _, incomingCall in ipairs(incomingCallsResult) do
    for _, fromRange in ipairs(incomingCall.fromRanges) do
      local reference = {}
      reference.uri = incomingCall.from.uri
      reference.range = fromRange
      reference.message = incomingCall.from.name
      table.insert(referencesResult, reference)
    end
  end
  return referencesResult
end

---@return Item[]
function M.incomingCalls(win, buf, cb, _options)
  local method = "callHierarchy/incomingCalls"
  local params = util.make_position_params(win, buf)
  params.context = { includeDeclaration = true }
  call_hierarchy(buf, method, params, function(err, result)
    if err then
      util.error("error happened getting incomingCalls: " .. err.message)
      return cb({})
    end
    if result == nil or #result == 0 then
      return cb({})
    end
    local tab = incomingCallsResultToReferencesResult(result)

    local ret = util.locations_to_items({ tab }, 0)
    cb(ret)
  end)
end

---@return Item[]
function M.references(win, buf, cb, _options)
  local method = "textDocument/references"
  local params = util.make_position_params(win, buf)
  params.context = { includeDeclaration = true }
  lsp_buf_request(buf, method, params, function(err, result)
    if err then
      util.error("an error happened getting references: " .. err.message)
      return cb({})
    end
    if result == nil or #result == 0 then
      return cb({})
    end
    local ret = util.locations_to_items({ result }, 0)
    cb(ret)
  end)
end

---@return Item[]
function M.implementations(win, buf, cb, _options)
  local method = "textDocument/implementation"
  local params = util.make_position_params(win, buf)
  params.context = { includeDeclaration = true }
  lsp_buf_request(buf, method, params, function(err, result)
    if err then
      util.error("an error happened getting implementation: " .. err.message)
      return cb({})
    end
    if result == nil or #result == 0 then
      return cb({})
    end
    local ret = util.locations_to_items({ result }, 0)
    cb(ret)
  end)
end

---@return Item[]
function M.definitions(win, buf, cb, _options)
  local method = "textDocument/definition"
  local params = util.make_position_params(win, buf)
  params.context = { includeDeclaration = true }
  lsp_buf_request(buf, method, params, function(err, result)
    if err then
      util.error("an error happened getting definitions: " .. err.message)
      return cb({})
    end
    if result == nil or #result == 0 then
      return cb({})
    end
    for _, value in ipairs(result) do
      value.uri = value.targetUri or value.uri
      value.range = value.targetSelectionRange or value.range
    end
    local ret = util.locations_to_items({ result }, 0)
    cb(ret)
  end)
end

---@return Item[]
function M.type_definitions(win, buf, cb, _options)
  local method = "textDocument/typeDefinition"
  local params = util.make_position_params(win, buf)
  lsp_buf_request(buf, method, params, function(err, result)
    if err then
      util.error("an error happened getting type definitions: " .. err.message)
      return cb({})
    end
    if result == nil or #result == 0 then
      return cb({})
    end
    for _, value in ipairs(result) do
      value.uri = value.targetUri or value.uri
      value.range = value.targetSelectionRange or value.range
    end
    local ret = util.locations_to_items({ result }, 0)
    cb(ret)
  end)
end

return M
