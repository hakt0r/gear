###

  * c) 2010-2015 Sebastian Glaser <anx@ulzq.de>

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

return unless $require ->
  @apt tor: 'tor'
  @mod 'task'
  @mod 'auth' unless $config.hostid and $config.hostid.onion

$path.tor = $path.join $path.configDir,'tor'
pr = $path.join $path.tor, 'private_key'
pp = $path.join $path.tor, 'public_key'
rc = $path.join $path.tor, 'torrc'

$bool = (val,def)-> if val then val isnt 'false' else def

$config.tor        = $config.tor        || {}
$config.tor.port   = $config.tor.port   || 2004
$config.tor.ctrl   = $config.tor.ctrl   || 2005
$config.tor.active = $bool $config.tor.active, true

$app.on tor:
  connecting: (p)-> console.log 'tor[' + $config.hostid.onion + ':' + p + '0%]'
  connected:     -> console.log 'tor[' + $config.hostid.onion + ':online]'

$app.once 'tor:connecting', ->
  console.log "tor: " + ' connecting ' + $config.hostid.onion

$config.tor.active = yes
$app.emit 'tor:connected'

$app.on 'daemon', ->
  return if $config.tor.active is false
  deps = 0
  $async.series [
    (s)-> $async.parallel [
      (c)-> $fs.exists pr, (exists)-> deps++ if exists; do c
      (c)-> $fs.exists pp, (exists)-> deps++ if exists; do c ], s
    (s)->
      return do s if deps is 2
      $fs.mkdirp $path.dirname(pr), (error)->
        process.exit 1, console.error error if error
        o = $onion()
        $async.parallel [
          (c)-> $fs.writeFile pr, o.pem, c
          (c)-> $fs.writeFile pp, o.pem_public, c ], s
    (c)-> $fs.chmod $path.tor, parseInt('700',8), c
    (c)-> $fs.readFile pp, (error,data)->
      process.exit 1, console.error error if error
      $config.hostid.onion = $onion( data.toString 'utf8' ).onion
      do c
    (c)-> $fs.writeFile rc, """
        SocksPort #{$config.tor.port}
        CookieAuthentication 1
        ControlPort #{$config.tor.ctrl}
        DataDirectory #{$path.join $path.configDir,'tor'}
        HiddenServiceDir #{$path.join $path.configDir,'tor'}
        HiddenServicePort 22
        HiddenServicePort 2003\n
      """, c
  ], ->
    do $app.sync
    $app.emit 'tor:setup'
    new Process
      name:'tor'
      command: [ $which('tor'),'-f',rc]
      autostart: $config.tor.active is true
      filter:->
        highest = 0
        log = (args)-> for line in args.trim().split('\n')
          if ( r = line.match /([0-9]{1,3}?)%/ )
            r = highest = Math.max highest, Math.floor .1 * parseInt r
            $app.emit 'tor:connecting', r
            $app.emit 'tor:connected' if r is 10
          else console.log 'tor', line
        [@instance.stdout,@instance.stderr].map (io)-> io.on 'data', log
