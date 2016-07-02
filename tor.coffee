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
  @mod 'auth' unless $auth? and $auth.onion?

$path.tor   = $path.join $path.configDir,'tor'
$path.torrc = $path.join $path.tor, 'torrc'

$config.tor        = $config.tor      || {}
$config.tor.port   = $config.tor.port || 2004
$config.tor.ctrl   = $config.tor.ctrl || 2005
$config.tor.active = Boolean.default $config.tor.active, true

$app.on 'tor:connecting', (p) -> console.log 'tor[' + $auth.onion + ':' + p + '0%]'
$app.on 'tor:connected',      -> console.log 'tor[' + $auth.onion + ':online]'
$app.on 'daemon', ->
  return if $config.tor.active is false
  return unless $fs.existsSync path = $path.ca 'me_onion.pub'
  o = $onion $fs.readFileSync path, 'utf8'
  $auth.onion = o.onion
  $fs.mkdirp.sync path unless $fs.existsSync path = $path.tor
  $fs.chmodSync path, parseInt '700', 8
  $fs.writeFileSync $path.torrc, """
  SocksPort #{$config.tor.port}
  CookieAuthentication 1
  ControlPort #{$config.tor.ctrl}
  DataDirectory #{$path.join $path.configDir,'tor'}
  HiddenServiceDir #{$path.join $path.configDir,'tor'}
  HiddenServicePort 22
  HiddenServicePort 2003
  """ unless $fs.existsSync $path.torrc
  $fs.symlinkSync $path.ca('me_onion.pem'), path unless $fs.existsSync path = $path.join $path.tor, 'private_key'
  $fs.symlinkSync $path.ca('me_onion.pub'), path unless $fs.existsSync path = $path.join $path.tor, 'public_key'
  do $app.sync
  $app.emit 'tor:setup'
  new Process name:'tor', command: [ $which('tor'),'-f',$path.torrc], autostart:on, filter:->
    highest = 0
    log = (args)-> for line in args.trim().split('\n')
      if ( r = line.match /([0-9]{1,3}?)%/ )
        r = highest = Math.max highest, Math.floor .1 * parseInt r
        $app.emit 'tor:connecting', r
        $app.emit 'tor:connected' if r is 10
      else console.debug 'tor', line
    [@instance.stdout,@instance.stderr].map (io)-> io.on 'data', log
