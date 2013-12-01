used = []
loaded = []

VALIDE_PLUGIN_FUNNAMES = <[
  process-opts
  isactive
  initialize
  ]>

VALIDE_HOOKNAMES = <[
  posthook-cli-create-plx
  posthook-cli-create-app
  prehook-cli-mount-auth
  posthook-cli-create-server
  posthook-cli-server-listen
  ]>

ensured-plugin = ->
  unless it.isactive?
    throw "plugin does not have isactive function!"
  errs = []
  for jsname, v of it
    if typeof v == \function
      lsfnname = camel2dash jsname
      if lsfnname in VALIDE_PLUGIN_FUNNAMES
        continue
      unless VALIDE_HOOKNAMES[jsname]?
        errs.push "- #lsfnname"

  if errs.length > 0
    errs.splice(0, 0, "plugin uses unsupported hooks:")
    throw errs.join "\n"
  it

export function use (plugin)
  used.push ensured-plugin plugin

export function init-plugins (opts)
  for plugin in used
    if plugin.process-opts?
      plugin.process-opts opts
    if plugin.isactive opts
      if plugin.initialize?
        plugin.initialize!
      loaded.push plugin

export function invoke-hook (hookname, ...args)
  for plugin in loaded
    hook = plugin[normalized-hookname hookname]
    if hook
      hook ...args

dash2camel = -> it.replace /(?:^|\s)\S/g, -> it.toUpperCase!
camel2dash = -> it.replace /([a-z\d])([A-Z])/g, '$1-$2' .toLowerCase!

normalized-hookname = (hookname) ->
  [hd, ...tl] = hookname / \-
  if hd in <[prehook posthook]> and tl
    hd + (tl.map -> dash2camel it) * ''
  else
    throw "invalid hook name #hookname"
