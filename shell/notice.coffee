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

return unless $config.i3
return unless $require ->
  @mod 'rpc'
  @npm 'dbus-native'

$app.on 'daemon', ->
  try # FIXME: don't do the hotpatching
    _patch = 'reply.body = \[result\]'
    _with  = 'reply.body = result[0] === "K_RAW_RESULT" ? result.slice(1) : [result]'
    _data  = $fs.readFileSync ( p = require.resolve 'dbus-native/lib/bus.js' ), 'utf8'
    console.log '$path$', p
    $fs.writeFileSync p, _data.replace _patch, _with unless -1 is _data.search _patch
  catch error then ( console.error error; process.exit 1 )
  do Notice.DBus.Server

$command notest: ->
  done = $$.defer 'wait-notice'
  s = $app.sticker summary:'TEST', click: -> s.close()

$app.sticker = (opts)->
  opts = _.defaults opts,
   app_name:'gear'
   replaces_id:0
   expire_timeout:0
  console.log opts
  new Notice opts

$app.notice = (opts)->
  opts = _.defaults opts,
   app_name:'gear'
   replaces_id:0
   expire_timeout:-1
  new Notice opts

class Notice
  constructor:(opts)->
    $evented @
    unless 0 is replaces_id = opts.replaces_id
      return n.update opts if ( n = Notice.byId[replaces_id] )
      return
    { @app_name, @replaces_id, @app_icon, @summary, @body, @actions, @hints, @expire_timeout, @click } = opts
    @id = Notice.getId()
    Notice.byId[@id] = @
    @expire_timeout = Notice.defaultTimeout if @expire_timeout is -1
    unless @expire_timeout is 0
      setTimeout(@close.bind(@),@expire_timeout)
    @name = @summary
    @full = @body
    @url = 'notice:' + @id
    $app.emit 'notice', @
    # Index.push @
  update:(opts)->
    @emit            'update', @, opts
    $app.emit 'notice:update', @, opts
    { @app_name, @replaces_id, @app_icon, @summary, @body, @actions, @hints, @expire_timeout, @click } = opts
    @name = @summary
    @full = @body
  close:->
    @emit            'close', @
    $app.emit 'notice:close', @
    Notice.byId[@id] = null
    # Index.pop @

Notice.defaultTimeout = 1500

Notice.byId   = {}
Notice.lastId = 0
Notice.getId  = ->
  id = 1 if Number.MAX_SAFE_INTEGER is id = ++Notice.lastId
  id

Notice.DBus =
  Notify: (app_name,replaces_id,app_icon,summary,body,actions,hints,expire_timeout)->
    n = new Notice app_name:app_name,replaces_id:replaces_id,app_icon:app_icon,summary:summary,body:body,actions:actions,hints:hints,expire_timeout:expire_timeout
    n.id
  CloseNotification: (id)->
    n.close() if ( n = Notice.byId[id] )
    null
  GetCapabilities:-> # all of them:)
    [ "action-icons","actions","body","body-hyperlinks","body-images","body-markup","icon-multi","persistence","sound" ]
  GetServerInformation:->
    ['K_RAW_RESULT','node-notice','anx','0.0.1','1.2']
  emit: (name, param1, param2)->
    console.log 'signal emit', name, param1, param2
    return
  Server: -> if process.env.DBUS_SESSION_BUS_ADDRESS
    $dbus = require 'dbus-native'
    bus = $dbus.sessionBus()
    name = 'org.freedesktop.Notifications'
    path = '/org/freedesktop/Notifications'
    bus.requestName name, 0
    bus.exportInterface Notice.DBus, path,
      name: name
      methods:
        GetCapabilities: ['y'                     ,'as']
        Notify: ['s','u','s','s','s','a','e','i'   ,'u']
        CloseNotification: ['u'                    ,'u']
        GetServerInformation: ['y'              ,'ssss']
      signals:
        NotificationClosed: ['u','u']
        ActionInvoked: ['u','s']
