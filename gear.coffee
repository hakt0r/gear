#!/usr/bin/env coffee
###

  * c) 1998-2016 Sebastian Glaser <anx@ulzq.de>

  This file is part of gear.

  gear is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  gear is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with gear.  If not, see <http://www.gnu.org/licenses/>.

###
### IRAC IRAC IRAC   IRAC IRAC *         * IRAC *         * IRAC IRAC
         IRAC        IRAC      IRAC   IRAC      IRAC   IRAC
         IRAC        IRAC IRAC        IRAC IRAC IRAC   IRAC
         IRAC        IRAC      IRAC   IRAC      IRAC   IRAC
    IRAC IRAC IRAC   IRAC      IRAC   IRAC      IRAC      * IRAC ###

$logo = (get)->
  _logo = """
                          ░▒▒░  .gear.irac.taskd.fleetlink.wantumeni.lastresort. ░▒░
                      ░░▒▓█▓                                                       ▒▓██▓  ░
                  ░▓░████▓               c) 1998-2016 Sebastian Glaser               ▓███▓░▓▓  ░
                ░█▓░▓███░▒                                                             ▓░▓▓██▓ ██▓
             ░▓██▓▒███▓▒▓              l) GNU General Public License v3                ▒▓ ▓▓█▓ ▓██▓
           ░▒▓██▓░▓▒░▒█▒                                                               ░██▓░▒▓ ▓██▓],
          ░▒▓█▓█ ░▒█▒█▒     █▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░      ▓███▓▒▓██▓ █c
         ░█▓▒█▓▒███▒░     █▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░      ▓▒█▓█▓█▓ m█k
        ░██░ Wmm█W(_[     █▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒      ▓░▒▓███▓ █WW.
        ░██░ m@ _m█f      ▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒░ order vision action - LltR ▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒       ▓██▓ ▓▒)███(
        ░███.[.█W█E       ▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒        ▒▓██▓▒)W██(
      ░;-███]███';        ▓▒▒▒▒▒▒▒▒▒▒▒▒░░░░░▒▒▒▒▒░░░░░░░░░░░░▓▒▒▒▒▒░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒         ▒ ▓██k██E ]f
      ██ -W███` m[        ▒▒▒▒▒▒▒▒▒▒▒░       ▓▒▒▒░           ▓▒▒▒░       ▓▒▒▒▒▒▒▒▒▒▒▒         ▒▓▒ ▓██f ]██
      ██k )█@ _██;        ▒▒▒▒▒▒▒▒▒▒░         ▓▒▒░▄▄▄▄▄▄▄▄▄▄▄▓▒▒░         ▓▒▒▒▒▒▒▒▒▒▒         ▓██▒ 4W .██k
      ░███,] j██k         ▒▒▒▒▒▒▒▒▒▒▒░       ▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░       ▓▒▒▒▒▒▒▒▒▒▒▒          ▓██▓ ']███[
      ░███[ .███f         ▒▒▒▒▒▒▒▒▒▒▒▒▒░░░▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒          ▓███k]███']
      ,░███(d██f.c       █▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░        ▓ ▓██m██W`.█
      ░ ░██░▓██.=█,      ▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░       ░▓░ █░WF  d█f
      ░█/ )░██( j█k      ▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░       ▓█▓ ▒▓P  y██(
      ░█░. ]██( ███      ▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░      ░███ ▓█jWW█@`
       ░███░.)(:███:     ▓▒▒▒▒▒▒▒▒▒▒▒▒▒░  ▓▒▒░    ▓▒▒▒▒▒▒▒▒▒░    ▓▒▒░  ▓▒▒▒▒▒▒▒▒▒▒▒▒▒░     ░▓███▓▓ ███F
         +░███░:███;:,   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒░  ▓▒▒░░▓▓▓▓▒▒▒▒▒▒▒▒▒░░▓▓▓▓▒▒░  ▓▒▒▒▒▒▒▒▒▒▒▒▒▒░   ▒▓ ▓███░░█▒░▒▓
         ( 4W██m]██f ]█m     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░     ░▓█▓ ▓█▓▒█████
          -█m,  "███[ $██L                                                            ▒██▓ ▓█▓░  ░▓█▓
            4██ma  "$/)W██[<,          we were always at war with snowden         ▒░▒███▒▓▒  ▒▓███▒
               -4██████w/██m )██6                                             ░▒██▒░██▓▒██████▓▒
                 {, -?H█WW███k 4███g.                                      _████▓ ▒███▓▓▒░  ░▒▓
                  -$█w,,.    -"`-4████/                                 ░▒▓██▓▒ ▒░  ░▒░░▒▓█▓▒
                      "$████████████W███T"~-_ww████████▓▒▒██▓▓▓██▓▒▒░░▒▒▓▓▓████████████▓░
                          "█gaa,_aawm███████W(  w██P`       ▒▓▓▒░ ░▒▓████████▓░░░▒▓█▓░
                             "4██████████P~  _██W^            ▒▓▓█▒  ░▒▓████████▓▒░
                                          -$██^                  ▒▓█▓▒
                                           -4[                    ░▓░
  """; _cmap = [[0,"31",26],[26,"32",48],[74,"31",5],[79,"31",26],[105,"33",48],[153,"31",12],[165,"31",26],
    [191,"33",48],[239,"31",17],[256,"31",26],[282,"33",48],[330,"31",19],[349,"31",26],[375,"33",48],[423,"31",20],
    [443,"31",96],[539,"31",18],[557,"33",63],[620,"31",16],[636,"31",18],[654,"33",63],[717,"31",17],[734,"31",18],
    [752,"33",63],[815,"31",18],[833,"31",18],[851,"33",63],[914,"31",18],[932,"31",18],[950,"33",63],[1013,"31",18],
    [1031,"31",18],[1049,"33",63],[1112,"31",20],[1132,"31",18],[1150,"33",63],[1213,"31",20],[1233,"31",18],
    [1251,"33",63],[1314,"31",20],[1334,"31",18],[1352,"33",63],[1415,"31",20],[1435,"31",18],[1453,"33",63],
    [1516,"31",20],[1536,"31",18],[1554,"33",63],[1617,"31",20],[1637,"31",18],[1655,"33",63],[1718,"31",20],
    [1738,"31",18],[1756,"33",63],[1819,"31",20],[1839,"31",18],[1857,"33",63],[1920,"31",19],[1939,"31",18],
    [1957,"33",63],[2020,"31",17],[2037,"31",18],[2055,"33",63],[2118,"31",17],[2135,"31",22],[2157,"33",56],
    [2213,"31",18],[2231,"31",96],[2327,"31",33],[2360,"33;1",27],[2387,"31",8],[2395,"0",0],[2395,"31",26],
    [2421,"31",91],[2512,"31",90],[2602,"31",88],[2690,"31",84],[2774,"31",81],[2855,"31",78],[2933,"31",65],
    [2998,"31",63],[3061,"0",0]]; _enemy = ['eastasia ','oceania  ','eurasia  ','assange ','snowden ','adamwhite']
  _logo = _logo.replace /snowden  /, _enemy.random
  o = ( ( '\x1b[' + esc + 'm') + _logo.substr(pos,len) for [ pos, esc, len ] in _cmap ).join ''
  return o if get
  print = process.stderr.write.bind process.stderr; print '\n\n\n'; print o; print '\n\n\n'

global.$static = (args...) -> while a = do args.shift
  if ( t = typeof a ) is 'string' then global[a] = do args.shift
  else if a::? and a::constructor? and a::constructor.name?
    global[a::constructor.name] = a
  else ( global[k] = v for k,v of a )
  null

global.$app =  new ( EventEmitter = require('events').EventEmitter )
global.$os =   require 'os'
global.$fs =   require 'fs'
global.$cp =   require 'child_process'
global.$util = require 'util'
global.$path = require 'path'
global.$logo = $logo
global.$nullfn = ->
global.$evented = (obj)-> Object.assign obj, EventEmitter::; EventEmitter.call obj; obj.setMaxListeners(0); return obj
global.$function = (members,func)-> unless func then func = members else ( func[k] = v for k,v of members ); func
global.$which = (name)-> w = $cp.spawnSync 'which',[name]; return false if w.status isnt 0; return w.stdout.toString().trim()

unless process.version[1].match /[456]/
  console.log """ERROR: nodejs is too old
    Please use at least v4 available from:
      https://nodejs.org/download/release/latest-v4.x/"""
  process.exit 1

do -> # COLORS Module [: what i need in ansi formatting, nothing really :]
  colormap = bold:1, inverse:7, black:30, red:31, green:32, yellow:33, blue:34, purple:35, cyan:36, white:37, error:'31;1;7', ok:'32;1;7', warn:'33;1;7', bolder:'37;1;7', log:'34;1;7'
  COLORS = require('tty').isatty() and not process.env.NO_COLORS
  String._color = if COLORS then ( (k)-> -> '\x1b[' + k  + 'm' + @ + '\x1b[0m' ) else -> -> @
  Object.defineProperty String::, name, get: String._color k for name, k of colormap

$app.setMaxListeners 0
process.title = """GEAR_#{process.pid}"""
process.on 'exit', $app.emit.bind $app, 'exit'

### DGB DBG *     DBG DBG DBG   DBG DBG *     DBG     DBG     * DBG DBG
    DGB     DBG   DBG           DBG     DBG   DBG     DBG   DBG
    DGB     DBG   DBG DBG DBG   DBG DBG *     DBG     DBG   DBG   * DBG
    DGB     DBG   DBG           DBG     DBG   DBG     DBG   DBG     DBG
    DGB DBG *     DBG DBG DBG   DBG DBG *       * DBG DBG     * DB###

$static $debug: $function active:no, hardcore:no, (fn) -> do fn if $debug.active and fn and fn.call
$debug.enable = (debug=no,hardcore=no)->
  @verbose = yes; @debug = debug || hardcore; @hardcore = hardcore
  c._log = log = c.log unless log = ( c = console )._log; start = Date.now();
  c.log = (args...)-> log.apply c, ['['+(Date.now()-start)+']'].concat args
  c.verbose = log; c.debug = ( if @debug then log else $nullfn ); c.hardcore = ( if @hardcore then log else $nullfn )
  c.log '\x1b[43;30mDEBUG MODE\x1b[0m', @debug, @hardcore, c.hardcore
$debug.disable = -> $debug.active = no; c = console; c.log = c._log || c.log; c.hardcore = c.debug = c.verbose = ->
unless -3 is process.argv.indexOf('-D') + process.argv.indexOf('-d') + process.argv.indexOf('-v')
  $debug.enable -1 isnt process.argv.indexOf('-d'), -1 isnt process.argv.indexOf('-D')
else do $debug.disable

unless -1 is process.argv.indexOf('-Q')
  try process.stderr.close() if process.stderr
  try process.stdout.close() if process.stdout
  try process.stdin.close()  if process.stdin
  try process.stderr.write = ->
  console.log = console.error = console.verbose = console.debug = console.hardcore = ->
  $util.print = ->
  process.on 'uncaughtException', (error)-> $fs.appendFileSync __dirname + '/error.log', JSON.stringify error

### REQ REQ *     REQ REQ REQ     * REQ *     REQ     REQ   REQ REQ REQ   REQ REQ *     REQ REQ REQ
    REQ     REQ   REQ           REQ     REQ   REQ     REQ       REQ       REQ     REQ   REQ
    REQ REQ *     REQ REQ REQ   REQ     REQ   REQ     REQ       REQ       REQ REQ *     REQ REQ REQ
    REQ     REQ   REQ           REQ     *     REQ     REQ       REQ       REQ     REQ   REQ
    REQ     REQ   REQ REQ REQ     * REQ REQ     * REQ REQ   REQ REQ REQ   REQ     REQ   REQ REQ ###

$static $require: (callback) ->
  ( Error.prepareStackTrace = (err, stack) -> stack ); ( try err = new Error ); ( file = do -> while err.stack.length then return f if __filename isnt f = err.stack.shift().getFileName() ); ( delete Error.prepareStackTrace )
  mod = $require.Module.byName[name = $require.modName(file)]
  mod.deps = callback
  do mod.checkDeps

$require.modName = (file) ->
  f = file.replace(/\.js$/,'').replace($path.cache+'/','')
  if $path.basename(f) is $path.basename($path.dirname f) then f = $path.dirname f else f

$require.compile = (source) =>
  dest = source.replace($path.modules,$path.cache).replace(/coffee$/,'js')
  return dest if $fs.existsSync(dest) and Date.parse($fs.statSync(source).mtime) is Date.parse($fs.statSync(dest).mtime)
  $fs.mkdirSync(dir) unless $fs.existsSync dir = $path.dirname(dest)
  $fs.writeFileSync dest, '#!/usr/bin/env node\n' + $coffee.compile $fs.readFileSync source, 'utf8'
  $fs.touch.sync dest, ref: source
  console.debug '\x1b[32m$compiled\x1b[0m', $require.modName dest
  dest

$require.scan = (base) -> Object.collect base, (dir,cue)->
  $fs.readdirSync(dir).map( (i)-> $path.join dir, i ).filter (i) ->
    return false if i is __filename or i.match 'node_modules'
    cue i        if $fs.statSync(i).isDirectory()
    i.match /\.(js|coffee)$/

$require.all = (callback) ->
  $require.scan($path.modules).map($require.compile).map (file)-> new $require.Module file
  $async.series [ $require.apt.commit, $require.npm.commit ], ->
    setImmediate retryRound = ->
      console.hardcore 'WAITING_FOR', Object.keys($require.Module.waiting).join ' '
      do mod.reload for name, mod of $require.Module.waiting
      return setImmediate retryRound unless 0 is Object.keys($require.Module.waiting).length
      $app.emit 'init', defer = $async.defer callback
      do defer.engage



$require.Module = class GEARModule
  @waiting: {}
  @byPath: {}
  @byName: {}
  constructor: (@path)->
    $require.Module.byPath[@path] = $require.Module.byName[@name = $require.modName @path] = @
    require @path
    if ( @deps and @loaded ) or ( not @deps? )
      console.hardcore '\x1b[33mmodule\x1b[0m', @name, @loaded, @deps?
      return @loaded = true
    @loaded = false
  reload: ->
    return unless @checkDeps()
    delete require.cache[@path]
    require @path
  checkDeps: ->
    done = yes; mods = $require.Module.byName
    if @deps then @deps.call {
    defer: => unless @resolve
      done = no
      @defer = $nullfn; console.hardcore '<defer>', @name
      @resolve = =>
        delete @resolve; @loaded = true; console.hardcore '<resolved>', @name
    apt:    (args) => done = done && $require.apt args
    npm: (args...) => done = done && $require.npm.apply null, args
    mod: (args...) => for mod in args
      done = done && mods[mod]? && mods[mod].loaded
    }, @
    if done then delete $require.Module.waiting[@name]
    else $require.Module.waiting[@name] = @
    return if done and @resolve then true else if done then @loaded = true else @loaded = false



$require.npm = $function queue: {}, list: {}, source: {}, (list...) ->
  n = $require.npm; wait = false
  for k in list
    if k.match ' '
      [ k, url ] = k.split ' '
      n.source[k] = url
    n.list[k] = true
    n.queue[k] = n.list[k] = wait = true unless $fs.existsSync $path.join $path.node_modules, k
  not true is wait

$require.npm.now = (list,callback) ->
  return do callback if $require.npm.apply null, list
  $require.npm.commit callback

$require.npm.commit = (callback)->
  queue = ( n = $require.npm ).queue; n.queue = {}
  install = Object.keys(queue).map (i)-> n.source[i] || i
  if install.length is 0
    return do callback
  session = $cp.spawn 'npm', ['install'].concat(install), stdio:'inherit'
  session.on 'close', -> do callback



$require.apt = $function queue: {}, missing: {}, (list) ->
  wait = false
  for k,v of list
    continue if $fs.existsSync(k) or $which(k) or $require.apt.missing[k]
    wait = true ; $require.apt.queue[k] = v
  not true is wait

$require.apt.commit = (callback=->)->
  queue = $require.apt.queue; $require.apt.queue = {}
  return do callback if ( install = ( v for k,v of queue ) ).length is 0
  session = $sudo ['apt-get','install','--no-install-recommends','--no-install-suggests','-y'].concat(install), stdio:'inherit', (p,done)-> do done; p.on 'close', ->
    for app, pkg of queue when not $which app
      console.error 'ERROR:', app, 'is missing and cannot be installed'
      # process.exit(0)
      $require.apt.missing[app] = true
    do callback

### INI INI INI  INI     INI   INI INI INI   INI INI INI
        INI      INI *   INI       INI           INI
        INI      INI INI INI       INI           INI
        INI      INI   * INI       INI           INI
    INI INI INI  INI     INI   INI INI INI       ###

setImmediate $app.init = ->
  # argv
  argv = process.argv.slice()
  i = 0; while i++ < argv.length
    if argv[i].match /gear(-daemon|\.js|\.coffee)$/
      argv.splice(0,i+1); break
      console.hardcore "\x1b[32mCOMMANDLINE\x1b[0m", argv
  $app.argv = argv
  # core environment
  r = $cp.spawnSync('getent',['passwd',process.getuid()]).stdout.toString().trim().split(':')
  process.env.USER          = r[0] unless process.env.USER
  process.env.HOME          = r[5] unless process.env.HOME
  process.env.SHELL_DEFAULT = r[6] unless process.env.SHELL_DEFAULT
  unless process.env.DISPLAY
    success = no
    for i in $fs.readdirSync('/tmp/') when ( m = i.match /^\.X([0-9]+)-lock$/ )
      process.env.DISPLAY = ':' + m[1]
      if $cp.spawnSync('xset',['-q']).status is 0
        success = yes; break
    delete process.env.DISPLAY unless success
  # $path[configDir|modules|bin|node_modules|cache]
  subconf = $path.dirname $path.configDir = conf = process.env.GEAR || $path.join process.env.HOME,'.config','gear'
  $path[dir] = $path.join conf, dir for dir in ['cache','node_modules','modules','bin']
  $path.node = $which('nodejs') || $which('node')
  $fs.mkdirSync(dir) for dir in [subconf,conf,$path.cache,$path.node_modules,$path.bin] when not $fs.existsSync(dir)
  ( console.log 'Error: could not open or create:', conf; process.exit 1 ) unless $fs.existsSync(conf)
  if process.cwd() isnt conf
    process.chdir conf
  unless $fs.existsSync(p = $path.join conf,'modules')
    $fs.symlinkSync $path.join(__dirname), p
  unless $fs.existsSync(p = $path.join conf,'package.json')
    try $fs.unlinkSync p
    $fs.symlinkSync $path.join($path.modules,'package.json'), p
  # process.env.PATH
  system = process.env.PATH.split(':').filter $fs.existsSync
  system = [ process.env.HOME+'/bin',$path.bin,'/usr/local/bin','/usr/local/sbin','/usr/local/libexec','/opt/bin','/opt/sbin','/opt/libexec','/usr/bin','/usr/sbin','/usr/libexec','/sbin','/bin','/libexec','/system/bin','/system/sbin','/system/xbin' ]
    .filter $fs.existsSync
    .filter (i)-> system.indexOf(i) is -1
    .concat system
  unique = {}; system.map (i)-> unique[i] = true
  system = Object.keys unique
  process.env.PATH = system.join(':')
  console.hardcore(
    "USER:", process.env.USER,
    '\n' + "HOME:", process.env.HOME,
    '\n' + "SHELL_DEFAULT:", process.env.SHELL_DEFAULT,
    '\n' + "DISPLAY:", process.env.DISPLAY,
    '\n' + "ARGS:", $app.argv,
    '\n' + "PATH:", process.env.PATH )
  do $app.init.resolveCache
  do $app.init.deps

$app.init.deps = -> # load deps, or install via npm
  console.hardcore 'INIT-DEPS'
  deps = ['underscore','coffee-script','mkdirp','touch','carrier','request','cbor','kexec']
  g = global; f = $fs
  try [ g._, g.$coffee, f.mkdirp, f.touch, g.$carrier, g.$request, g.$cbor, $cp.kexec ] = deps.map (i)->
    require $path.join $path.node_modules, i
  catch e
    if $app.init.deps.failed
      console.error __filename, e.stack.toString()
      process.exit 1
    $app.init.deps.failed = true
    $require.npm.now deps, $app.init.deps
  console.hardcore 'INIT-DEPS-DONE', Object.keys($async).length
  do $app.init.reload
  do $app.init.config

$app.init.reload = ->
  need_restart = __filename isnt $path.join $path.cache,'gear.js'
  need_restart_harmony = process.requireFeature? and not process.env.RESTART_HARMONY
  if need_restart or need_restart_harmony
    args = [$require.compile $path.join $path.configDir,'modules','gear.coffee']
    if need_restart_harmony
      process.env.RESTART_HARMONY = yes
      args.unshift '--harmony_object'         if process.version[1] is '4'
      args.unshift '--harmony_object_observe' if process.version[1] is '6'
      args = process.requireFeature.concat(args).unique
    args = args.concat $app.argv
    console.hardcore 'RE-EXECUTING', $which('node'), args
    if $cp.kexec then $cp.kexec $which('node'), args
    else return require path

$app.init.config = ->
  $app.config = new Storage
    default: global.$config = {}
    name: 'config'
    preWrite:-> return ( [k,v] for k,v of $config )
    revive:(d)-> $config[d[0]] = d[1]
    firstRead: (config)->
      global.$config = Object.monitor $config, ->
        console.hardcore ' CONFIG-CHANGED '.warn
        do $app.sync
      $app.on 'sync', -> $app.config.write()
      do $app.init.main

$app.init.main = ->
  argv = $app.argv
  if ( fnc = $app.cli[cmd = argv.shift()] )
    r = fnc.apply $app, argv
    $require.all => $app.emit 'ready'
  else process.exit 1, console.error "Command not found: ", cmd, argv

###   * CAC CAC     * CAC *       * CAC CAC   CAC     CAC   CAC CAC CAC
    CAC           CAC     CAC   CAC           CAC     CAC   CAC
    CAC           CAC CAC CAC   CAC           CAC CAC CAC   CAC CAC CAC
    CAC           CAC     CAC   CAC           CAC     CAC   CAC
      * CAC CAC   CAC     CAC     * CAC CAC   CAC     CAC   CAC CAC ###

$app.init.resolveCache = ->
  timer = null
  $static $cache: try JSON.parse $fs.readFileSync( fpath = $path.join $path.cache, 'resolve.json' ) catch e then {}
  $cache.write = -> clearTimeout timer; timer = setTimeout ( ->
    $fs.writeFile fpath, JSON.stringify $cache ), 500
  $cache.get = (key)-> $cache[key]
  $cache.add = (key,value)-> $cache.write $cache[key] = value
  return
  return if ( Module = require 'module' ).__resolveFilename
  console.hardcore ' RESOLVE-CACHE '.error
  nodeModule = {}; Object.keys(process.binding('natives')).forEach (n) -> nodeModule[n] = yes
  Module.__resolveFilename = Module._resolveFilename
  Module._resolveFilename = (r,s) ->
    return r if nodeModule[r]
    return val if ( val = $cache[cpath = if r.match /^\./ then s.filename+"///"+r else r] )?
    do $cache.write
    return $cache[cpath] = try Module.__resolveFilename.call this,r,s catch e then undefined
  Module._resolveFilename[k] = o for k,o of Module.__resolveFilename

$app.init.cache = ->
  console.log 'fscache', 'active'
  try cache = $bson.deserialize $fs.readFileSync cache_path = $path.join $path.cache, 'libcache.bson' catch e then cache = {}
  add = (key,data)-> cache[key] = data; do write
  get = (key,data)-> cache[key]
  timer = null; write = clearTimeout timer; timer = setTimeout ( -> $fs.writeFile cache_path, $bson.serialize cache ), 500
  $fs._readFileSync = $fs.readFileSync
  $fs.readFileSync = (path)->
   if path and path.match and path.match $path.node_modules
     return c if c = cache[cpath = path.replace $path.node_modules,'']
     add cpath, val = $fs._readFileSync.apply $fs, arguments
     do write; return val
   else $fs._readFileSync.apply $fs, arguments
  $fs.readFileSync[n] = p for n,p of $fs._readFileSync
  $cache.fs = get:get, add:add
  null

###   * CFG CFG     * CFG *     CFG     CFG   CFG CFG CFG   CFG CFG CFG     * CFG C*
    CFG           CFG     CFG   CFG *   CFG   CFG               CFG       CFG
    CFG           CFG     CFG   CFG CFG CFG   CFG CFG           CFG       CFG   * CFG
    CFG           CFG     CFG   CFG   * CFG   CFG               CFG       CFG     CFG
      * CFG CFG     * CFG *     CFG     CFG   CFG           CFG CFG CFG     * C ###

$static Storage: class Storage
  constructor: (opts)->
    Object.assign $evented(@), opts
    @default = @default || []
    @suffix  = @suffix  || '.cbor'
    @basedir = @basedir || $path.configDir
    @path    = @path    || $path.join @basedir, @name + @suffix
    @temp    = @temp    || @path + '.tmp'
    @[k] = ( @[k] || (data) => data ) for k in ['revive','firstRead','filter','preWrite']
    ( @decode  = @decode  || new $cbor.Decoder() ).on 'data', @revive || (data)-> data
    $async.series [ @setup, @read ], ( @firstRead || $nullfn ).bind @
    $app.on 'exit', @writeSync = =>
      console.log ' ERMERGENCY-WRITE '.error, @name
      $fs.writeSync @temp, @preWrite(@data).map(@filter).map($cbor.encode)
      $fs.renameSync @temp, @path
  revive:(data)=> @data.push data
  setup:(done=$nullfn)=> $fs.exists @basedir, (exists)=> return do done unless exists; $fs.mkdirp @basedir, done
  write:(done=$nullfn)=>
    return if @out
    pos = 0; @encode = new $cbor.Encoder(); data = @preWrite @data
    @encode.pipe @out = $fs.createWriteStream @temp
    write = @encode.write.bind @encode; len = data.length
    @out.on 'drain', next = =>
      # console.hardcore @name.ok, ' DRAIN '.warn, pos, len
      data.slice(pos,1000).map(@filter).map(write)
      if ( pos += 1000 ) > len
        @out.removeListener 'drain', next
        @encode.end()
      null
    @out.on 'close', =>
      # console.hardcore @name.ok, ' CLOSE '.warn
      $fs.rename @temp, @path, =>
        # console.hardcore @name.ok, ' RENAME '.warn
        delete @out
        do done
    do next
  read:(done=$nullfn)=> $fs.exists @path, (exists)=>
    return done null, @data = @default unless exists
    $fs.createReadStream(@path).pipe(@decode).on('end',done).on('error',=> done null, @data = @default )

$app.resolveId = (id)->
  return r for test in $app.resolvePlugin when ( r = test id )?
  return false
$app.resolvePlugin = [ (id)-> if id is 'config' then return $config; null ]

$app.propertyAction = (mode,path,value)->
  return false unless mode and path and ( value? or mode isnt 'set' )
  list = (item)-> Object.keys if key then item[key] else item
  get = (item)-> if key then item[key] else item
  set = (item)-> if key then item[key] = value else item = value
  id = ( path = path.split '.' ).shift(); key = path.pop()
  return false unless id and item = $app.resolveId id
  return false unless ( path.length is 0 ) or item = Object.resolve item, path.join '.'
  apply = if mode is 'set' then set else if mode is 'get' then get else list
  # console.log mode, path, id, key, value, Object.keys item
  JSON.stringify (
    if item.list or item.map
      apply i for i in items = if Array.isArray item then item else if item.list then item.list else [item]
    else apply item )

###   * CMD CMD     * CMD *     CMD     CMD   CMD     CMD     * CMD *     CMD     CMD   CMD CMD *
    CMD           CMD     CMD   CMD CMD CMD   CMD CMD CMD   CMD     CMD   CMD *   CMD   CMD     CMD
    CMD           CMD     CMD   CMD     CMD   CMD     CMD   CMD CMD CMD   CMD CMD CMD   CMD     CMD
    CMD           CMD     CMD   CMD     CMD   CMD     CMD   CMD     CMD   CMD   * CMD   CMD     CMD
      * CMD CMD     * CMD *     CMD     CMD   CMD     CMD   CMD     CMD   CMD     CMD   CMD C ###

$app.cli =
  help:   (args...)-> Object.keys $app.cli
  set: (path,value)-> $app.propertyAction 'set',  path, value
  get:       (path)-> $app.propertyAction 'get',  path
  list:      (path)-> $app.propertyAction 'list', path
  unset:     (path)-> $app.propertyAction 'del',  path
  restart:->
    if $which 'systemctl' then $cp.spawnSync 'systemctl',['--user','restart','gear']
    else do process.cli.stop; do process.cli.start
  start:->
    if $which 'systemctl' then $cp.spawnSync 'systemctl',['--user','restart','gear']
    else $cp.spawn $path.join($path.bin,'gear-daemon'),['daemon','-Q'], detach:yes, stdio:null; process.exit 0
  stop:->
    if $which 'systemctl' then $cp.spawnSync 'systemctl',['--user','stop','gear']
    else $cp.spawn 'kill',[parseInt $fs.readFileSync p, 'utf8'] if $fs.existsSync p = $path.join($path.cache,'daemon.pid')
  daemon:->
    $fs.writeFileSync ($path.join $path.cache,'daemon.pid'), process.pid
    do $logo
    $app.emit 'daemon:init'
    $app.on 'ready', -> $app.emit 'daemon'
  install: (pkg...)-> $app.on 'ready', ->
    console.log 'INSTALLING GEAR'
    if pkg.length is 0
      UID = ( process.getuid || -> 0 )()
      { USER, HOME } = process.env
      GEAR = $path.join $path.modules, 'gear.coffee'
      if $which 'systemd'
        $fs.mkdirp.sync d = $path.join HOME,'.local','share','systemd','user'
        $fs.writeFileSync ( f = $path.join d, 'gear.service' ), """
          [Unit]
          Description=GEAR Service
          [Service]
          Type=simple
          TimeoutStartSec=0
          ExecStop=-#{$path.bin + '/gear'} shutdown
          ExecStartPre=-#{$path.bin + '/gear'} shutdown
          ExecStart=#{$which 'coffee'} #{GEAR} daemon
          [Install]
          WantedBy=default.target
        """
        $cp.script """
          sudo -A loginctl enable-linger #{USER}
          systemctl --user | grep -q gear.service &&
          systemctl --user disable gear
          systemctl --user enable #{f}
          systemctl --user restart gear
        """, -> console.log '__ GEAR WAS SUCCESSFULLY INSTALLED TO SYSTEMD __'; process.exit(0)
      else if '/etc/rc.local' then $sudo.script """
        if cat /etc/rc.local | grep "# gear-#{UID}"
        then echo "\x1b[32mAlready installed to \x1b[33m/etc/rc.local\x1b[0m"
        else awk '{if(p)print p;p=$0;}END{
            print "sudo -u #{USER} nodejs #{HOME}/.config/gear/bin/gear-daemon start & # gear-#{UID}"; print p; exit(0)}
          ' /etc/rc.local > /etc/rc.local.new
          cat /etc/rc.local.new | grep "# gear-#{UID}" | sh
        fi
      """, -> do process.cli.start
    else switch ( pkg = pkg.shift() )
      when 'npm' then $require.npm.install.now pkg
      when 'sys' then $require.apt.install.now pkg
      else console.log 'Don\'t know how to install:', pkg

###   * CLB CLB     * CLB *     CLB CLB *     CLB CLB CLB   CLB           CLB CLB CLB   CLB CLB *
    CLB           CLB     CLB   CLB     CLB   CLB           CLB               CLB       CLB     CLB
    CLB           CLB     CLB   CLB CLB *     CLB CLB CLB   CLB               CLB       CLB CLB *
    CLB           CLB     CLB   CLB     CLB   CLB           CLB               CLB       CLB     CLB
      * CLB CLB     * CLB *     CLB     CLB   CLB CLB CLB   CLB CLB CLB   CLB CLB CLB   CLB CL###

### process enhancements ###
process.cpus = (
  try $fs.readFileSync('/proc/cpuinfo','utf8').match(/processor/g).length
  catch e then 1 )

### $util enhancements ###
$util.print = -> process.stdout.write arguments[0]
$util.debuglog = $util.debuglog || -> ->

### Type enhancements ###
Boolean.default = (val,def)-> if val then val isnt 'false' else def

### Array enhancements ###
Object.defineProperties Array::,
  trim:get:          -> return ( @filter (i)-> i? and i isnt false ) || []
  last:get:          -> @[@length-1]
  first:get:         -> @[0]
  random:get:        -> @[Math.round Math.random()*(@length-1)]
  unique:get:        -> u={}; @filter (i)-> return u[i] = on unless u[i]; no
( (k)-> Array[k] = (a)-> a[k] )( k ) for k in ['trim','last','first','unique','random']

Array::remove       = (v) -> @splice i, 1 if i = @indexOf v; @
Array::pushUnique   = (v) -> @push v if -1 is @indexOf v
Array::commons      = (b) -> @filter (i)-> -1 isnt b.indexOf i
( (k)-> Array[k] = (a,v)-> a[k](v) )( k ) for k in ['remove','pushUnique','commons']

Array.slice         = (a,c) -> Array::slice.call a||[], c
Array.oneSharedItem = (b)-> return true for v in @ when -1 isnt b.indexOf v; false

Array.blindPush = (o,a,e)->
  list = o[a] || o[a] = []
  list.push e if -1 is list.indexOf e

Array.blindSortedPush = (o,a,e,key='date')->
  return o[a] = [e] unless ( list = o[a] ) and list.length > 0
  return            unless -1 is list.indexOf e
  return list.unshift e if list[0][key] > e[key]
  break for item, idx in list when item[key] > e[key]
  list.splice idx, 0, e

Array.blindConcat = (o,a,e)->
  o[a] = ( o[a] || o[a] = [] ).concat e

Array.destructiveRemove = (o,a,e)->
  return unless list = o[a]
  list.remove e
  delete o[a] if list.length is 0

### Object enhancements ###
Object.keyCount = (o)-> Object.keys(o).length

Object.resolve = (o,path)->
  ( path = o; o = global ) unless path?
  return o if not path or path is ''
  return false for k in ( l = path.split '.' ) when not ( o = o[k] )?
  return o

Object.unroll = (obj, handle)->
  cue = [].concat obj; cat = cue.concat.bind cue
  if typeof o is 'object' and not Array.isArray o then cat o else handle o, cat while o = do cue.shift
  null

Object.collect = (obj,handle)->
  res = []; cue = [].concat obj; push = cue.push.bind cue; push = cue.push.bind cue
  res = res.concat handle cue.shift(), push while cue.length > 0
  return res

Object.trim = (map)->
  for key,val of map
    delete map[key] if Array.isArray(val)  and val.length is 0
    delete map[key] if typeof val is 'object' and Object.keys(val).length is 0
  map

if ( not Object.monitor? ) and Proxy? then do ->
  monitor_stack = (obj,handler)->
    has: (name) -> return name in obj
    keys: keys = -> Object.keys obj
    ownKeys: keys
    set: (receiver, name, val) ->
      handler 'set', obj, name, obj[name] = ( if val? and ( c = val.__TARGET__ )? then c else val ); true
    delete: (name) -> handler 'del', obj, name; delete obj[name]
    get: (receiver, name) ->
      return undefined             unless ( v = obj[name] )?
      return v                         if name is '__TARGET__'
      return fn.bind obj               if fn = Object::[name]
      return Object.monitor v, handler if typeof v is 'object'
      return v
    enumerate: -> Object.keys obj
    iterate: -> p = keys(); i = 0; l = p.length; return next: -> if i is l then throw StopIteration else p[i++]
    getOwnPropertyDescriptor: (name) -> desc.configurable = true unless undefined is desc = Object.getOwnPropertyDescriptor(obj, name); desc
  ES6Proxy    = (obj,f,p='@')-> new Proxy obj, monitor_stack obj.__TARGET__ || obj, f
  NodeJSProxy = (obj,f,p='@')-> Proxy.create   monitor_stack obj.__TARGET__ || obj, f
  Object.monitor = if Proxy.create then NodeJSProxy else ES6Proxy
  Object.isMonitored = (o)-> o.__TARGET__?
  Object.pure = (o)-> o.__TARGET__ || o
else if process and process.versions.node and not process.env.RESTART_HARMONY
  l = process.requireFeature = process.requireFeature = []
  l.push f if -1 is l.indexOf f = '--harmony-proxies'
else console.error """
  ERROR: Can't enable ( Object.monitor )
  - this practically means there are no ES-Proxies available.
  - Please update your JS-engine or install a supplemantary plugin
    and require it in: {$path.join $path.configDir,'hacks.js'}
  DEVELOPER INFORMATION: #{JSON.stringify platform:process.platform, arch: process.arch, version:process.versions}
"""; process.exit 1

### $pipe tools ###
$static $pipe: catchErrors: (p)->
  p.on 'error', $nullfn
  p.stdin.on  'error', $nullfn if p.stdin
  p.stdout.on 'error', $nullfn if p.stdout
  p.stderr.on 'error', $nullfn if p.stderr

### $cp enhancements ###
$cp.sane = (i)-> [i.stderr,i.stdout,i.stdin].map( (i)-> i.setEncoding 'utf8'); i

$cp.readlines = (cmd,args...,callback)->
  console.debug '$cp.readlines', cmd, args
  c = $cp.sane $cp.spawn cmd,args
  $carrier.carry c.stdout, callback
  $carrier.carry c.stderr, (line)-> callback line, 'error'
  c

$cp.script = (cmd,callback=->)->
  console.debug '$cp.script', cmd
  c = $cp.sane if cmd.stdout then cmd else $cp.spawn "sh", ["-c",cmd]
  c.buf = []
  $carrier.carry c.stdout, push = (line)-> c.buf.push line
  $carrier.carry c.stderr, push
  c.on 'close', (e)-> callback(e, c.buf.join().trim())
  c

$cp.console = (args...)->
  if process.env.DISPLAY
       return $cp.spawn 'xterm', ['-e'].concat args
  else return $cp.spawn args.shift(), args, stdio:'inherit'

$cp.ssh = (args...)->
  return $cp.console.apply null, ['ssh','-tXA'].concat args

$cp.ssh.cli = (args...)->
  return $cp.spawn('ssh', [`process.env.DISPLAY?'-XA':'-t'`].concat(args), stdio:'inherit')

$cp.ssh.pipe = (args...)->
  return $cp.spawn('ssh', ['-T'].concat(args), stdio:'pipe')

$cp.expect = (cmd)-> new Expect cmd

class Expect
  expect: null
  constructor: (@cmd,@onopen) ->
    @expect = []
    $sudo [ 'sh','-c',@cmd], @run
  run: (@proc,done) =>
    setImmediate done
    $cp.sane @proc
    $carrier.carry @proc.stdout, @data
    $carrier.carry @proc.stderr, @data
    @proc.on 'close', => @onend @ if @onend
    @onopen @ if @onopen
  on:     (match,cb=->) => @expect.push [match,cb]; @
  end:         (@onend) => @
  open:       (@onopen) => @
  data:          (line) => for rec in @expect when ( match = line.match rec[0] )
    rec[1] line, match
    break

### $async functions / inpired by npm:async ###
$static $async: {}

$async.series = (list,done=$nullfn)->
  setImmediate next = (error,args...)->
    return done.call ctx, error, args      if error
    return fn.apply  ctx, [next].concat args if fn = list.shift()
    return done.call ctx
  ctx = list:list, done:done

$async.parallel = (list,done=$nullfn)->
  return done null, [] if list.length is null
  result = new Array list.length; error = new Array list.length; count=0;
  finish = -> done ( if error.length is 0 then null else error ), result
  cb = (i,fn)-> fn (e,a...)-> error[i] = e; result[i] = a; if ++count is list.length then do finish
  cb idx, fn for fn, idx in list
  null

$async.limit = (token,timeout,callback)->
  unless callback
    callback = timeout
    timeout  = 0
  clearTimeout t if ( t = $limit[token] )
  $limit[token] = setTimeout callback, 0

$async.cue = (worker)->
  q = (task...)-> tip cue.push task
  q.cue = cue = []; running = no
  tip = -> unless running
    return running = no unless task = cue.shift()
    running = yes; worker task, -> tip running = no
  return q

$async.debug = (e,c,o=5000)-> late = no; return (d) ->
  console.hardcore '+>>', e
  t = setTimeout ( -> late =  yes; console.error 'late:', e ), o
  c ->
    if late then console.debug 'resolved', e else console.hardcore '<<-', e
    clearTimeout t
    d null

$async.deadline = (deadline,worker)->
  running = no; timer = null; cue = []
  reset = -> return running = no if cue.length is 0; setImmediate guard
  guard = -> running = yes; worker cue.slice(), reset; cue = []
  return trigger = ->
    cue.push arguments
    return if running
    timer && clearTimeout timer
    timer = setTimeout guard, deadline
    null

$async.pushup = (opts)->
  { worker, threshold, deadline } = opts
  timer = running = again = null; cue = []
  reset = -> setImmediate guard if again; running = again = no
  guard = -> running = yes; worker cue.slice(), reset; cue = []
  return ->
    cue.push arguments
    return again = true if running
    if cue.length < threshold
      clearTimeout timer
      timer = setTimeout guard, deadline
    else clearTimeout timer; setImmediate guard

$async.throttle = (interval,key,callback)->
  unless ( k = $async.throttle[key] )
    k = $async.throttle[key] = interval:interval,key:key,callback:callback,last:0,timer:null
  return if k.timer
  if ( t = Date.now() ) > ( next = k.last + k.interval )
    delta = 0
  else delta = next - t
  k.timer = setTimeout ( ->
    k.last = t
    k.timer = null
    do callback
  ), delta

$async.defer = (fn) -> return o = $function
  task: {}
  waiting: []
  final: fn || $nullfn
  count: 0
  engage: ->
    if o.count is 0 and o.final
      f = o.final
      delete o.final
      f null
  after: (name,deps,fnc)->
    done = o name
    for d in deps when not o.task[d] or o.task[d].done
      f = -> fnc done
      f.__name = name
      f.deps = deps
      o.waiting.push f
      return null
    fnc done
    null
  (task) -> # part
    ++o.count
    o.task[id = task||o.count] = 'pending'
    # console.hardcore 'defer-task:', id
    return -> # join
      # console.hardcore 'finish-task:', id
      o.task[id].done = true
      for fnc in o.waiting
        continue if fnc.done
        continue for d in fnc.deps when not o.task[d] or o.task[d].done
        fnc.done = true
        fnc null
      if --o.count is 0 and o.final
        f = o.final
        delete o.final
        f null
      null

### sync-queue ###
$app.sync = $async.deadline 100, (cue, done)->
  $app.emit 'sync', cue, defer = $async.defer ->
    $app.emit 'sync:complete'
    done null
    null
  do defer.engage
  null
$app.syncAdd    = $app.sync.bind null, 'add'
$app.syncChange = $app.sync.bind null, 'change'
$app.syncRemove = $app.sync.bind null, 'remove'

### $sudo helper ###
unless process.env.SUDO_ASKPASS
  process.env.SUDO_ASKPASS = w if w = $which 'ssh-askpass'

$static $sudo: $async.cue (task,done)->
  [ args, opts, callback ] = task
  unless typeof opts is 'object'
    callback = opts
    opts = {}
  do done unless ( args = args || [] ).length > 0
  args.unshift '-A' if process.env.DISPLAY
  sudo = $cp.spawn 'sudo', args, opts
  console.log '\x1b[32mSUDO\x1b[0m', args.join ' '
  if callback then callback sudo, done
  else sudo.on 'close', done

$sudo.read = (cmd,callback)-> $sudo ['sh','-c',cmd], (proc,done)->
  $cp.sane proc
  proc.stdout.once 'data', -> done null
  $carrier.carry proc.stdout, callback

$sudo.script = (cmd,callback)-> $sudo ['sh','-c',cmd], (sudo,done)->
  do done; $cp.sane sudo; out = []; err = []
  $carrier.carry sudo.stdout, out.push.bind out
  $carrier.carry sudo.stderr, err.push.bind out
  sudo.on 'close', (status)-> callback status, out.join('\n'), err.join('\n')
