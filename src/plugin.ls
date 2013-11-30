used = []

export function use (plugin)
  unless plugin.isactive?
    throw "try to use invalid plugin!"
  used.push plugin

export function init-plugins (opts)
  for plugin in used
    if plugin.isactive opts
      plugin.initialize!

export function invoke-hook (hookname, ...args)
  for plugin in used
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
