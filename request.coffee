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

return unless $require ->
  @npm 'socksjs git+https://github.com/hakt0r/socksjs', 'mime'

socksjs = require 'socksjs'
https   = require 'https'

$path.shared = $path.join $path.configDir, 'shared'
$path.sharedHash = (hash) -> $path.join $path.shared, hash
$fs.mkdirSync $path.shared unless $fs.existsSync $path.shared

$app.on 'web:listening', ->
  $web.static = require('serve-static')($path.shared)
  $web.wss.on "connection", (socket)->
    $auth.verify socket, socket._socket, true
    Request.acceptSocket socket
    null

$static Request: (peer,args,callback) ->
  { irac } = peer
  { queue, active } = Request
  a = active[irac] = active[irac] || active[irac] = []
  q = queue[irac]  = queue[irac]  || queue[irac]  = []
  q.push arguments
  a.counter = 0 unless a.counter?
  if Request.socket[irac]
    clearTimeout Request.queue.dirty
    Request.queue.dirty = setImmediate ->
      Request.flush peer
  else Request.connect peer

Request.WebSocket = require 'ws'

Request.queue      = {}
Request.active     = {}
Request.socket     = {}
Request.connecting = {}
Request.connected  = {}

Request.flush = (peer)->
  return ( console.error 'IRAC-REQUEST-NO-SOCKET'; false ) unless socket = Request.socket[irac = peer.irac]
  return ( console.error 'IRAC-REQUEST-NO-QUEUE';  false ) unless queue  = Request.queue[irac]
  return ( console.error 'IRAC-REQUEST-NO-ACTIVE'; false ) unless active = Request.active[irac]
  for request in queue
    request.uid = uid = ++active.counter
    socket.send [REQUEST,uid,request[1]]
    active.push request
    # console.hardcore 'IRAC-REQUEST-REPLAY', irac, uid, request[1]
  Request.queue[irac] = []
  true

Request.Agent = (opts) ->
  https.Agent.call @, opts
  @protocol = 'https:'
  @createConnection = (opts) ->
    host = opts.host
    _error = (stage)-> (error)->
      console.hardcore 'SOCKSJS'.red.inverse, 'error:' + stage, error
    remote = ssl:yes, ca:opts.ca, cert:opts.cert, key:opts.key, host:opts.host, port: opts.port
    socks  = host:"127.0.0.1", port:$config.tor.port, localAddress: '127.0.0.1'
    socket = new socksjs remote, socks
    socket.on 'error', _connect_error = _error 'connect'
    socket.on 'connect', ->
      socket.removeListener 'error', _connect_error
      socket.on 'error', _error 'closed'
    socket
  return

$util.inherits Request.Agent, https.Agent

Request.tlsOpts = (peer,protocol)->
  opts = {}
  opts.peer = peer
  opts.requestCert = yes
  opts.rejectUnauthorized = yes
  opts.key = $config.hostid.key
  opts.ca = if peer.ca then peer.ca else $config.hostid.cachain
  opts.cert = peer.cert || $config.hostid.cert
  if peer.local is on
    opts.url = protocol + '://' + peer.address + ':2003/rpc/'
    return opts
  opts.url = protocol + '://' + peer.onion + '.onion:2003/rpc/'
  opts.agent = new Request.Agent opts
  opts

Request.retry = $function
  block: -> Request.retry.status = 'closed'
  unblock: ->
    Request.retry.status = 'open'
    (Request.retry.hold || []).map (callback)-> do callback
    Request.retry.hold = []
  (timeout,callback)-> setTimeout ( ->
      if Request.retry.status is 'closed'
        Request.retry.hold.push callback
      else do callback
    ), timeout
do Request.retry.unblock

Request.static = (peer,args,callback) ->
  opts = Request.tlsOpts peer, 'https'
  opts.rejectUnauthorized = no
  opts.method = 'POST'
  opts.body = args
  opts.json = true
  # console.hardcore 'REQUEST'.green.inverse, peer, args[0]
  do req = -> $request( opts, (e)-> callback.apply null, arguments unless e ).on 'error', (msg)->
    return Request.retry 10000, req if msg      is 'SOCKS: Host unreachable'
    return Request.retry 10000, req if msg      is 'SOCKS: TTL expired'
    return Request.retry 5000,  req if msg.code is 'ECONNREFUSED'
    console.log "IRAC-REQUEST-ERROR", arguments[0]
  null

Request.pipe = (peer,args,target,callback) ->
  opts = Request.tlsOpts peer, 'https'
  opts.url += args.map(encodeURIComponent).join('/')
  $request.get(opts).pipe(target)
  null

Request.connect = (peer) -> do req = ->
  return ( console.debug 'IRAC-WSC-ALREADY-CONNECTED';  true  ) if Request.socket[irac = peer.irac]
  return ( console.debug 'IRAC-WSC-ALREADY-CONNECTING'; false ) if Request.connecting[irac]
  session = {}; opts = Request.tlsOpts peer, 'wss'
  # console.hardcore 'IRAC-WSC-CONNECTING', opts.url
  socket = new Request.WebSocket opts.url, opts
  socket.on 'open', ->
    $auth.verify socket, socket._socket
    if Request.socket[irac]
      console.debug 'IRAC-WSC-DOUBLE', irac
      return socket.close()
    # console.debug 'IRAC-WSC-CONNECT', irac
    socket.removeListener 'error', connect_error
    Request.acceptSocket socket, peer
    null
  socket.on 'error', connect_error = (error)->
    return Request.retry 10000, req if error      is 'SOCKS: Host unreachable'
    return Request.retry 10000, req if error      is 'SOCKS: TTL expired'
    return Request.retry 5000,  req if error.code is 'ECONNREFUSED'
    console.error 'IRAC-WSC-CONNECT-ERROR', peer.irac, error
    delete Request.connecting[irac]
    null
  true

ERROR = -1; REQUEST = 0; RESPONSE = 1

Request.acceptSocket = (socket,peer)->
  unless socket.irac is $config.hostid.irac
    ( console.error 'IRAC-REQUEST-NO-PEER';  return false ) unless ( peer = peer || PEER[socket.cert.irac] )
    ( console.debug 'IRAC-WS-ALREADY-CONNECTED'; return false ) if Request.socket[peer.irac]
  else peer = $config.hostid
  console.hardcore 'IRAC-WS-ACCEPT', peer.irac

  delete Request.connecting[irac]
  Request.socket[irac = peer.irac] = socket
  Request.connected[irac] = peer
  peer.lastSeen = Date.now()
  Channel.byName.peer.push peer

  _send = socket.send.bind socket
  socket.send = ->
    # console.hardcore 'IRAC-WS-SEND', arguments
    _send JSON.stringify arguments[0]
    # socket.send( $bson.serialize([RESPONSE,uid,message],no,yes,no), binary:on, mask:on )

  socket.fail = (error,data)->
    console.error error, peer.irac, $util.inspect data
    socket.send [ -1, -1, [ error + "\n" + data ] ]

  socket.on "message", (m)->
    # console.hardcore 'IRAC-WS-MESSAGE', peer.irac, $util.inspect arguments
    try m = JSON.parse m
    catch e then return console.error "IRAC-WS-INVALID-JSON", peer.irac, $util.inspect m

    return socket.fail 'IRAC-WS-NOT-AN-ARRAY', m unless Array.isArray m

    [ msgType, uid, msg ] = m
    return socket.fail 'IRAC-WS-INVALID-STRUCTURE', m unless msgType? and uid? and msg? and msg.push?

    if msgType is REQUEST
      # console.hardcore 'IRAC-WS-RPC', uid, msg
      rpc = new $rpc.scope ws:socket, group:socket.group, cert:socket.cert, cmd:msg, reply: (args...)->
        socket.send [RESPONSE,uid,args]

    else if ( msgType is RESPONSE ) and ( queue = Request.active[irac] )?
      for request in queue.slice() when request.uid is uid
        if typeof ( callback = request[2] ) is 'function'
          callback.apply null, [null,uid].concat msg
        Array.remove queue, request
        break

    else if msgType is ERROR
      console.error "IRAC-WS-REMOTE-ERROR".red.inverse, msg.join '\n  '

    else console.error 'IRAC-WS-ILLEGAL', msgType, uid, msg
    null

  socket.on 'error', (error)->
    console.log 'IRAC-WS-ERROR', error
    null

  socket.on 'close', (error)->
    console.debug ' IRAC-WS-CLOSE '.blue.bold.inverse, peer.irac
    delete Request.socket[irac]
    delete Request.connecting[irac]
    delete Request.connected[irac]
    peer.lastSeen = Date.now()
    Channel.byName.peer.pull peer
    return if irac is $config.hostid.irac
    Request.connect peer
    null

  Request.flush peer
  null
