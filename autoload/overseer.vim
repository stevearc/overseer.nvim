function! overseer#task_bundle_completelist(arglead, cmdline, cursorpos) abort
  return luaeval('require("overseer.task_bundle").list_task_bundles()')
endfunction
