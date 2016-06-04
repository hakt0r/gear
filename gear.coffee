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
  _logo = _logo.replace /snowden  /, _enemy[Math.round(Math.random()*5)]
  o = ( ( '\x1b[' + esc + 'm') + _logo.substr(pos,len) for [ pos, esc, len ] in _cmap ).join ''
  return o if get
  print = process.stderr.write.bind process.stderr; print '\n\n\n'; print o; print '\n\n\n'


global.$static = (args...) -> while a = do args.shift
  if ( t = typeof a ) is 'string' then global[a] = do args.shift
  else if a::? and a::constructor? and a::constructor.name?
    global[a::constructor.name] = a
  else ( global[k] = v for k,v of a )
  null

$static
  $app:  new ( EventEmitter = require('events').EventEmitter )
  $os:   require 'os'
  $fs:   require 'fs'
  $cp:   require 'child_process'
  $util: require 'util'
  $path: require 'path'
  $logo: $logo
  $nullfn: ->
  $evented: (obj)->
    Object.assign obj, EventEmitter::; EventEmitter.call obj; obj.setMaxListeners(0); return obj
  $function: (members,func)->
    unless func then func = members else ( func[k] = v for k,v of members )
    func
  $which: (name)->
    w = $cp.spawnSync 'which', [name]
    return false if w.status isnt 0
    return w.stdout.toString().trim()
  $cue: collect: (init,callback)-> # recursion unroll with callback :D
    cue = if Array.isArray init then init else [init]
    add = cue.push.bind cue; res = []
    res = res.concat callback cue.shift(),add while cue.length > 0
    return res

$app.setMaxListeners 0
process.on 'exit', $app.emit.bind $app, 'exit'

### DGB DBG *     DBG DBG DBG   DBG DBG *     DBG     DBG     * DBG DBG
    DGB     DBG   DBG           DBG     DBG   DBG     DBG   DBG
    DGB     DBG   DBG DBG DBG   DBG DBG *     DBG     DBG   DBG   * DBG
    DGB     DBG   DBG           DBG     DBG   DBG     DBG   DBG     DBG
    DGB DBG *     DBG DBG DBG   DBG DBG *       * DBG DBG     * DB###

$static $debug: $function
  active:no
  hardcore:no
  enable:(debug=no,hardcore=no)->
    @verbose = yes; @debug = debug || hardcore; @hardcore = hardcore
    c._log = log = c.log unless log = ( c = console )._log; start = Date.now();
    c.log = (args...)-> log.apply c, ['['+(Date.now()-start)+']'].concat args
    c.verbose = log; c.debug = ( if @debug then log else $nullfn ); c.hardcore = ( if @hardcore then log else $nullfn )
    c.log '\x1b[43;30mDEBUG MODE\x1b[0m', @debug, @hardcore, c.hardcore
  disable:-> $debug.active = no; c = console; c.log = c._log || c.log; c.hardcore = c.debug = c.verbose = ->
  (fn) -> do fn if $debug.activ and fn and fn.call
unless -3 is process.argv.indexOf('-D') + process.argv.indexOf('-d') + process.argv.indexOf('-v')
  $debug.enable -1 isnt process.argv.indexOf('-d'), -1 isnt process.argv.indexOf('-D')
else do $debug.disable

### RPC RPC *     RPC RPC *       * RPC RPC
    RPC     RPC   RPC     RPC   RPC
    RPC RPC *     RPC RPC       RPC
    RPC     RPC   RPC           RPC
    RPC     RPC   RPC             * RPC ###

$static
  $$: console
  $group: (group...,fn)-> fn.group = group.concat( fn.group || [] ); fn
  $command: $function defaultHandler:{}, byType:{}, byName:{}, byGroup:{}, (obj)-> for k,v of obj
    v.group = ['$local'].concat v.group || []
    $rpc k, v
  $rpc: $function open:{}, (key,fn)->
    wrapper = eval """( function RPC_#{key}(){
      args = Array.prototype.slice.call(arguments)
      $$ = args[0] && args[0].reply && args[0].group ? args.shift() : console
      return ( #{fn.toString().replace(/\(/,key+' (')} ).apply(this,args) } )"""
    wrapper[k] = v for k in ['group'] when ( v = fn[k] )
    console.hardcore '\x1b[32mcommand >>>\x1b[0m', key
    $command.byName[key] = wrapper

class $rpc.scope
  constructor: (opts) ->
    Object.assign @, opts
    _cmd = @cmd
    return @error "Command not supplied: #{_cmd}" unless @cmd
    if Array.isArray @cmd then @args = @cmd
    else if @cmd.split    then @args = @cmd.split /[ \t]+/
    else return @error "Command not found: #{_cmd}"
    @args.pop() if ( @args[@args.length-1] || '' ).toString().trim() is ''
    @cmd = @args.shift()
    @fnc = $command.byName[@cmd] if @cmd.match
    return @error "Could not find #{_cmd}"                             unless @fnc?
    return @error "Not a function #{_cmd}"                             unless @fnc.apply? or @fnc.push?
    return @error "Access denied: #{_cmd}, no gorup"                   unless @group?
    return @error "Access denied: #{_cmd}, non-rpc function"           unless @fnc.group? and Array.isArray @fnc.group
    return @error "Access denied: have[#{@group}] need[#{@fnc.group}]" unless Array.commons(@fnc.group,@group).length > 0
    _reply = @reply; @reply = => @finish _reply.bind @, arguments[0]
    $rpc.open[@id = ++$rpc.serial] = @
    # console.debug '\x1b[32mRUN\x1b[0m', @cmd, ( if @item then '$' + @item.uid else '' )
    @defer = $async.defer =>
      # console.debug '\x1b[32mRESULT\x1b[0m', @return
      @reply @return unless @pipe
    try
      @return = @fnc.apply(@item,[@].concat @args)
      do @defer.engage
    catch error then @error 'exception', error.stack.toString()
  finish: (callback) ->
    if @done then return false else do callback
    delete $rpc.open[@id]; @ctx = @cmd = @args = @opts = @id = null
    @done = true
  error: (message,object=@cmd) ->
    console.error 'RPC-ERROR'.red.inverse, @cmd, message, object
    @reply error: message, errorData: object

console.rpc    =  '$local'
console.group  = ['$local']
console.defer  = ->->

###   * CMD CMD     * CMD *     CMD     CMD   CMD     CMD     * CMD *     CMD     CMD   CMD CMD *
    CMD           CMD     CMD   CMD CMD CMD   CMD CMD CMD   CMD     CMD   CMD *   CMD   CMD     CMD
    CMD           CMD     CMD   CMD     CMD   CMD     CMD   CMD CMD CMD   CMD CMD CMD   CMD     CMD
    CMD           CMD     CMD   CMD     CMD   CMD     CMD   CMD     CMD   CMD   * CMD   CMD     CMD
      * CMD CMD     * CMD *     CMD     CMD   CMD     CMD   CMD     CMD   CMD     CMD   CMD C ###

$command help: (args...) ->
  $$.reply Object.keys $command.byName

$command cset: (path,value) ->
  key = ( path = path.split('.') ).pop()
  return $$.error "Can't change a root object", path if path.length is 0
  if ( o = Object.resolve path = path.join '.' )
    if value is 'true' or value is 'false'
      o[key] = if value is 'true' then true else false
    if typeof value is 'string'
      o[key] = value
    $app.syncChange o
    $$.reply set:path+"."+key, value:o[key]

$command clist: (path) ->
  return unless ( o = Object.resolve path )
  if ( t = typeof o ).match /(string|number|boolean)/
    $$.reply o
  else $$.reply Object.keys(o.byName || o.byURL || o.byID || o )

$command shutdown: -> process.exit 0
$command linger:->

process.cli =
  daemon:->
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
      else if '/etc/rc.local' then $sudo ['sh','-c',"""
        [ -n "$EDITOR" && -f "$EDITOR" ] || which nano && EDITOR=nano
        [ -n "$EDITOR" && -f "$EDITOR" ] || which vim  && EDITOR=vim
        [ -n "$EDITOR" && -f "$EDITOR" ] || which vi   && EDITOR=vi
        if cat /etc/rc.local | grep "# gear-#{UID}"
        then echo "\x1b[32mAlready installed to \x1b[33m/etc/rc.local\x1b[0m"
        else awk '{if(p)print p;p=$0;}END{
            print "sudo -u #{USER} nodejs #{HOME}/.config/gear/cache/gear.js daemon >/dev/null 2>&1 & # gear-#{UID}"; print p}
          ' /etc/rc.local > /etc/rc.local.new
          $EDITOR /etc/rc.local.new
          cat /etc/rc.local.new | grep "# gear-#{UID}" || sh
        fi
      """]
    else switch ( pkg = pkg.shift() )
      when 'npm' then $require.npm.install.now pkg
      when 'sys' then $require.apt.install.now pkg
      else console.log 'Don\'t know how to install:', pkg

$command ssh_update: process.cli.ssh_update = (host)->
  $async.series [
    (c)=> $cp.exec """cd #{$path.modules} && tar cjvf - * | ssh #{host} 'cd ; cat - > .gear_setup.tbz'""", => do c
    (c)=> $cp.ssh( host, """
      cd; [ -f .gear_setup.tbz ] || exit 1
      systemctl --user stop gear
      mv .gear_setup.tbz .config/gear/modules/
      cd .config/gear/modules/
      tar xjvf .gear_setup.tbz
      rm -rf .gear_setup.tbz
      cd; coffee .config/gear/modules/gear.coffee install
      """ ).on 'close', -> do c
    ]

$command ssh_install: process.cli.ssh_install = (host)->
  $async.series [
    (c)=> $cp.exec """cd #{$path.modules} && tar cjvf - * | ssh #{host} 'cd ; cat - > .gear_setup.tbz'""", => do c
    (c)=> $cp.ssh( host, """
      [ -f .gear_setup.tbz ] || exit 1
      [ "$USER" = "root" ] && sudo= || sudo=sudo
      i=" "; a=" "
      which npm  ||                 i="$i npm"
      which node || which nodejs || i="$i nodejs"
      which ssh-askpass          || i="$i ssh-askpass"
      if [ ! "x${i}x" = "x x" ]; then
        $sudo apt-get update
        eval $sudo apt-get -y install $i
      fi
      which nodejs && [ ! which node ] && $sudo ln -sf $(which nodejs) /usr/bin/node
      which node && [ ! which nodejs ] && $sudo ln -sf $(which node) /usr/bin/nodejs
      which node-gyp || a="$a node-gyp"
      which coffee   || a="$a coffee-script"
      if [ ! "x${a}x" = "x x" ]; then
        $sudo npm -g install $a
      fi
      cd;
        rm -rf .gear_setup;
        mkdir .gear_setup;
      cd .gear_setup
        tar xjvf ../.gear_setup.tbz
        rm -rf   ../.config/gear ../.gear_setup.tbz
        coffee gear.coffee install
      cd
        rm .config/gear/modules &&
        mv .gear_setup .config/gear/modules
      echo done; read a
      """ ).on 'close', => do c ]
  null

### REQ REQ *     REQ REQ REQ     * REQ *     REQ     REQ   REQ REQ REQ   REQ REQ *     REQ REQ REQ
    REQ     REQ   REQ           REQ     REQ   REQ     REQ       REQ       REQ     REQ   REQ
    REQ REQ *     REQ REQ REQ   REQ     REQ   REQ     REQ       REQ       REQ REQ *     REQ REQ REQ
    REQ     REQ   REQ           REQ     *     REQ     REQ       REQ       REQ     REQ   REQ
    REQ     REQ   REQ REQ REQ     * REQ REQ     * REQ REQ   REQ REQ REQ   REQ     REQ   REQ REQ ###

$static $require: $function
  modName: (file) ->
    f = file.replace(/\.js$/,'').replace($path.cache+'/','')
    if $path.basename(f) is $path.basename($path.dirname f) then f = $path.dirname f else f
  compile: (source) =>
    dest = source.replace($path.modules,$path.cache).replace(/coffee$/,'js')
    # console.hardcore "compile", source
    return dest if $fs.existsSync(dest) and Date.parse($fs.statSync(source).mtime) is Date.parse($fs.statSync(dest).mtime)
    $fs.mkdirSync(dir) unless $fs.existsSync dir = $path.dirname(dest)
    $fs.writeFileSync dest, '#!/usr/bin/env node\n' + $coffee.compile $fs.readFileSync source, 'utf8'
    $fs.touch.sync dest, ref: source
    console.debug '\x1b[32m$compiled\x1b[0m', $require.modName dest
    dest
  scan: (base) -> $cue.collect base,(dir,cue)->
    $fs.readdirSync(dir).map( (i)-> $path.join dir, i ).filter (i) ->
      return false if i is __filename or i.match 'node_modules'
      cue i        if $fs.statSync(i).isDirectory()
      i.match /\.(js|coffee)$/
  all: (callback) ->
    $require.scan($path.modules).map($require.compile).map (file)-> new $require.Module file
    $async.series [ $require.apt.commit, $require.npm.commit ], ->
      setImmediate retryRound = ->
        console.hardcore 'WAITING_FOR', Object.keys($require.Module.waiting).join ' '
        do mod.reload for name, mod of $require.Module.waiting
        return setImmediate retryRound unless 0 is Object.keys($require.Module.waiting).length
        $app.emit 'init', defer = $async.defer callback
        do defer.engage
  (callback) ->
    return require callback if callback.match # handle: $require 'NPM-PACKAGE'
    ( Error.prepareStackTrace = (err, stack) -> stack ); ( try err = new Error ); ( file = do -> while err.stack.length then return f if __filename isnt f = err.stack.shift().getFileName() ); ( delete Error.prepareStackTrace )
    mod = $require.Module.byName[name = $require.modName(file)]
    mod.deps = callback
    do mod.checkDeps

$require.Module = class GEARModule
  constructor: (@path)->
    $require.Module.byPath[@path] = $require.Module.byName[@name = $require.modName @path] = @
    require @path
    if ( @deps and @loaded ) or ( not @deps? )
      console.hardcore '\x1b[33mmodule\x1b[0m', @name, @loaded, @deps?
      return @loaded = true
    @loaded = false
  reload: ->
    return unless @checkDeps()
    delete require.cache[@path]; require @path
  checkDeps: ->
    done = yes; mods = $require.Module.byName
    if @deps then @deps.call {
    defer: (key)=>
      @defer = $nullfn #; console.hardcore '<defer>', @name, key
      @resolve = =>
        delete @resolve; @loaded = true #; console.hardcore '<resolved>', @name
    apt:    (args) => done = done && $require.apt args
    npm: (args...) => done = done && $require.npm.apply null, args
    mod: (args...) => for mod in args
      done = done && mods[mod]? && mods[mod].loaded
    }, @
    if done then delete $require.Module.waiting[@name]
    else $require.Module.waiting[@name] = @
    return if done and @resolve then true else if done then @loaded = true else @loaded = false
  @waiting: {}
  @byPath: {}
  @byName: {}

$require.npm = $function
  queue: {}
  list: {}
  source: {}
  now: (list,callback) ->
    return do callback if $require.npm.apply null, list
    $require.npm.commit callback
  commit: (callback)->
    queue = ( n = $require.npm ).queue; n.queue = {}
    install = Object.keys(queue).map (i)-> n.source[i] || i
    if install.length is 0
      return do callback
    session = $cp.spawn 'npm', ['install'].concat(install), stdio:'inherit'
    session.on 'close', ->
      # require n for n in install
      do callback
  (list...) ->
    n = $require.npm; wait = false
    for k in list
      if k.match ' '
        [ k, url ] = k.split ' '
        n.source[k] = url
      n.list[k] = true
      n.queue[k] = n.list[k] = wait = true unless $fs.existsSync $path.join $path.node_modules, k
    not true is wait

$require.apt = $function
  queue: {}
  missing: {}
  commit: (callback=->)->
    queue = $require.apt.queue; $require.apt.queue = {}
    return do callback if ( install = ( v for k,v of queue ) ).length is 0
    session = $sudo ['apt-get','install','--no-install-recommends','--no-install-suggests','-y'].concat(install), stdio:'inherit', (p,done)-> do done; p.on 'close', ->
      for app, pkg of queue when not $which app
        console.error 'ERROR:', app, 'is missing and cannot be installed'
        # process.exit(0)
        $require.apt.missing[app] = true
      do callback
  (list) ->
    wait = false
    for k,v of list
      continue if $fs.existsSync(k) or $which(k) or $require.apt.missing[k]
      wait = true ; $require.apt.queue[k] = v
    not true is wait

### INI INI INI  INI     INI   INI INI INI   INI INI INI
        INI      INI *   INI       INI           INI
        INI      INI INI INI       INI           INI
        INI      INI   * INI       INI           INI
    INI INI INI  INI     INI   INI INI INI       ###

$app.init = {}

$app.init.main = ->
  argv = process.argv.slice()
  i = 0; while i++ < argv.length
    if argv[i].match /gear\.(js|coffee)$/
      argv.splice(0,i+1); break
  console.hardcore "\x1b[32mCOMMANDLINE\x1b[0m", argv
  if ( fnc = process.cli[cmd = argv.shift()] )
    r = fnc.apply $command, argv
  else process.exit 1, console.error "Command not found: ", cmd, argv
  $require.all => $app.emit 'ready'

setImmediate $app.init.bootstrap = ->
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
    '\n' + "PATH:", process.env.PATH )
  do $app.init.deps

$app.init.deps = -> # load deps, or install via npm
  do $app.init.corelib.resolveCache
  console.hardcore 'INIT-DEPS'
  deps = ['underscore','async','coffee-script','mkdirp','touch','carrier','request','colors','bson']
  load = ['underscore','async','coffee-script','mkdirp','touch','carrier','request']
  g = global; f = $fs
  try
    require $path.join $path.node_modules, 'colors'
    g.$bson = new ( require $path.join $path.node_modules, 'bson' ).BSONNative.BSON()
    [ g._, async, g.$coffee, f.mkdirp, f.touch, g.$carrier, g.$request ] = load.map (i)->
      require $path.join $path.node_modules, i
    $async[k] = v for k,v of async; g.$async = $async
    console.hardcore 'INIT-DEPS-DONE', Object.keys($async).length
    do $app.init.reload
  catch e
    process.exit 1 if $app.init.deps.failed;  $app.init.deps.failed = true
    console.error __filename, e.stack.toString()
    $require.npm.now deps, $app.init.deps

$app.init.reload = ->
  if __filename isnt $path.join $path.cache,'gear.js'
    console.hardcore 'RE-EXECUTING'
    return require $require.compile $path.join $path.configDir,'modules','gear.coffee'
  do $app.init.corelib

$app.init.corelib = ->
  do $app.init.corelib.config

###   * CAC CAC     * CAC *       * CAC CAC   CAC     CAC   CAC CAC CAC
    CAC           CAC     CAC   CAC           CAC     CAC   CAC
    CAC           CAC CAC CAC   CAC           CAC CAC CAC   CAC CAC CAC
    CAC           CAC     CAC   CAC           CAC     CAC   CAC
      * CAC CAC   CAC     CAC     * CAC CAC   CAC     CAC   CAC CAC ###

$app.init.corelib.resolveCache = ->
  Module = require 'module'
  return if Module.__resolveFilename
  console.log 'resolveCache'
  nodeModule = {}; timer = null
  try cache = JSON.parse $fs.readFileSync( fpath = $path.join $path.cache, 'resolve.json' ) catch e then cache = {}
  Object.keys(process.binding('natives')).forEach (n) -> nodeModule[n] = yes
  Module.__resolveFilename = Module._resolveFilename
  Module._resolveFilename = (r,s) ->
   return r if nodeModule[r]
   return val if ( val = cache[cpath = if r.match /^\./ then s.filename+"///"+r else r] )?
   clearTimeout timer; timer = setTimeout ( -> $fs.writeFile fpath, JSON.stringify cache ), 500
   return cache[cpath] = Module.__resolveFilename.call this,r,s
  Module._resolveFilename[k] = o for k,o of Module.__resolveFilename
  cache.get = (key)-> cache[key]
  cache.add = (key,value)-> cache[key] = value
  $static $cache: cache

$app.init.corelib.cache = ->
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

$app.init.corelib.config = ->
  $static Storage: class Storage
    path:        null
    data:        null
    lastSave:    null
    lastTimeout: null
    suffix:    '.bson'
    basedir:    $path.configDir

    constructor: (key,opts)->
      if typeof key is 'object' and not opts
        opts = key; key = opts.name
      Object.assign @, opts if opts and typeof opts is 'object'
      @path    = $path.join @basedir, key + @suffix
      @default = @default || []
      $evented @
      @[slot] = @[slot].bind @ for slot in ['write','writeSync']
      @write = $async.deadline 100, @write
      @onread = $nullfn unless @onread
      $app.on 'exit', @writeSync
      do @read

    read:->
      $async.series [
        (c)=> $fs.exists @basedir, (exists)=>
          return do c if exists
          console.hardcore 'CONFIG-MKDIR'
          $fs.mkdirp @basedir, c
        (c)=> $fs.exists @path, (exists)=>
          return do c unless exists
          console.hardcore 'CONFIG-READING', @path
          $fs.readFile @path, (error,data)=>
            process.exit 1, console.error 'STORAGE-READ', @path, error if error
            try @data = $bson.deserialize data; do c
            catch error then process.exit 1, console.error 'STORAGE-PARSE-ERROR', @path, error, error.stack
        (c)=>
          console.hardcore 'CONFIG-DONE', @path
          @data = @data || @default; @onread @data; @emit 'read', @data ]
      null

    stringify: (data)-> $bson.serialize data
    write: (cue,done)->
      return console.error 'CONFIG-NO-DATA', @path unless @data
      console.hardcore 'CONFIG-WRITE', @path
      data = if @_filter then @_filter @data else @data
      data = data.map( (o)-> c = {}; c[k] = v for k,v of o; delete c.uid; c ) if data.map
      temp = @path + '.tmp'
      @emit "write", d = @stringify data
      $async.series [
        (c)=> $fs.writeFile temp, d, c
        (c)=> $fs.rename temp, @path, c
      ], =>
        console.hardcore 'CONFIG-WRITE-DONE', @path
        done null
      null
    writeSync:->
      data = if @_filter then @_filter @data else @data
      data = data.map( (o)-> c = {}; c[k] = v for k,v of o; delete c.uid; c ) if data.map
      $fs.writeFileSync @path + '.tmp', @stringify data
      $fs.renameSync    @path + '.tmp', @path

  $app.config = new Storage
    name: 'config'
    default: {}
    onread: (config)->
      @onread = (config)-> global.$config = config
      @onread config
      do $app.init.main
    sync: -> $app.config.write()

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

  $app.on 'sync', $app.config.sync.bind $app.config

###   * CLB CLB     * CLB *     CLB CLB *     CLB CLB CLB   CLB           CLB CLB CLB   CLB CLB *
    CLB           CLB     CLB   CLB     CLB   CLB           CLB               CLB       CLB     CLB
    CLB           CLB     CLB   CLB CLB *     CLB CLB CLB   CLB               CLB       CLB CLB *
    CLB           CLB     CLB   CLB     CLB   CLB           CLB               CLB       CLB     CLB
      * CLB CLB     * CLB *     CLB     CLB   CLB CLB CLB   CLB CLB CLB   CLB CLB CLB   CLB CL###

### $util enhancements ###
$util.print = -> process.stdout.write arguments[0]
$util.debuglog = $util.debuglog || -> ->

### Type enhancements ###
Boolean.default = (val,def)-> if val then val isnt 'false' else def

### Array enhancements ###
Array.last    =   (a) -> a[a.length-1]
Array.remove  = (a,v) -> a.splice a.indexOf(v), 1
Array.random  =   (a) -> a[Math.round Math.random()*(a.length-1)]
Array.commons = (a,b) -> a.filter (i)-> -1 isnt b.indexOf i
Array.slice   = (a,c) -> Array::slice.call a||[], c
Array.unique  =   (a) -> u={}; a.filter (i)-> return u[i] = on unless u[i]; no
### process enhancements ###
process.cpus = (
  try $fs.readFileSync('/proc/cpuinfo','utf8').match(/processor/g).length
  catch e then 1 )

### Object enhancements ###
Object.resolve = (o,path)->
  ( path = o; o = global ) unless path
  path = ''                unless path
  path = path.replace /^@/, '$'
  l = path.split '.'
  while l.length > 0
    unless ( o = o[l.shift()] )
      return false
  return o

Object.unroll = (obj, handle)->
  cue = []
  push = (o)-> cue.push o
  push obj
  while cue.length > 0
    for k,v of o = do cue.shift
      handle v, push, typeof v is 'object' and not Array.isArray v

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

### Extensions to the [$]async module ###
$async = {} # async is not loaded yet

$async.debug = (e,c,o=5000)-> late = no; return (d) ->
  console.hardcore '+>>', e
  t = setTimeout ( -> late =  yes; console.error 'late:', e ), o
  c ->
    if late then console.debug 'resolved', e else console.hardcore '<<-', e
    clearTimeout t
    d null

$async.deadline = (deadline,worker)->
  running = no; timer = null; cue = []
  # sources = {}
  reset = ->
    return running = no if cue.length is 0
    setImmediate guard
  guard = ->
    # console.log '<sync-source>', f, v for f,v of sources; sources = {}
    running = yes
    worker cue.slice(), reset
    cue = []
  return trigger = ->
    cue.push arguments
    return if running
    timer && clearTimeout timer
    timer = setTimeout guard, deadline
    null

$async.pushup = (opts)->
  { worker, threshold, deadline } = opts
  timer = running = again = null
  cue   = []
  reset = ->
    setImmediate guard if again
    running = again = no
  guard = ->
    running = yes; c = cue.slice(); cue = []
    worker c, reset
  return ->
    cue.push arguments
    return again = true if running
    if cue.length < threshold
      clearTimeout timer
      timer  = setTimeout guard, deadline
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

$async.limit = (token,timeout,callback)->
  unless callback
    callback = timeout
    timeout  = 0
  clearTimeout t if ( t = $limit[token] )
  $limit[token] = setTimeout callback, 0

$async.cue = (worker)->
  cue = []; running = no
  tip = -> unless running
    return running = no unless task = cue.shift()
    running = yes; worker task, -> tip running = no
  (task...)-> tip cue.push task

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
