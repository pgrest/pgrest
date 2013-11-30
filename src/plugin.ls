used = []
loaded = []

export function use (plugin)
  unless plugin.isactive?
    throw "try to use invalid plugin!"
  used.push plugin

export function init-plugins (opts)
  for plugin in used
    if plugin.process-opts?
      plugin.process-opts opts
    if plugin.isactive opts
      plugin.initialize!
      loaded.push plugin

export function invoke-hook (hookname, ...args)
  for plugin in loaded
    hook = plugin[normalized-hookname hookname]
    if hook
      hook ...args

capitalize = -> it.replace /(?:^|\s)\S/g, -> it.toUpperCase!

normalized-hookname = (hookname) ->
  [hd, ...tl] = hookname / \-
  if hd in <[prehook posthook]> and tl
    hd + (tl.map -> capitalize it) * ''
  else
    throw "invalid hook name #hookname"
