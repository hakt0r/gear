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
    return @error "Access denied: #{_cmd}, no group"                   unless @group?
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
    console.error Peer.format(@peer), ' RPC-ERROR '.red.inverse, @cmd, message, object
    @reply error: message, errorData: object

console.rpc    =  '$local'
console.group  = ['$local']
console.defer  = ->->

$command help: $app.cli.help = (args...)->
  direct: Object.keys($app.cli).sort()
  remote: Object.keys($command.byName).sort()
$command set: $app.cli.set
$command get: $app.cli.get
$command list: $app.cli.list
$command unset: $app.cli.unset
$command shutdown: -> process.exit 0
$command linger: ->

$command ssh_update: $app.cli.ssh_update = (host)->
  $async.series [
    (c)=> $cp.exec """cd #{$path.modules} && tar cjvf - * | ssh #{host} 'cd ; cat - > .gear_setup.tbz'""", => do c
    (c)=> $cp.ssh( host, """
      cd; [ -f .gear_setup.tbz ] || exit 1
      gear-daemon stop || systemctl --user stop gear
      mv .gear_setup.tbz .config/gear/modules/
      cd .config/gear/modules/
      tar xjvf .gear_setup.tbz
      rm -rf .gear_setup.tbz
      cd; coffee .config/gear/modules/gear.coffee install
      """ ).on 'close', -> do c ]

$command ssh_install: $app.cli.ssh_install = (host)->
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
