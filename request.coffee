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
  @npm 'socksjs git+https://github.com/hakt0r/socksjs', 'mime', 'cbor-sync'

$cbor = require 'cbor-sync'

do -> unless ( dns = require 'dns' )._lookup
  dns._lookup = dns.lookup
  dns.lookup = (hostname,options,callback)->
    ( callback = options; options = {} ) unless callback?
    if ( peer = PEER[hostname] ) and peer.address
      dns._lookup peer.address, options, callback
    else dns._lookup hostname, options, callback

socksjs = require 'socksjs'
https   = require 'https'

$path.shared = $path.join $path.configDir, 'shared'
$path.sharedHash = (hash) -> $path.join $path.shared, hash
$fs.mkdirSync $path.shared unless $fs.existsSync $path.shared

$app.on 'web:listening', ->
  $web.wss.on "connection", (socket)->
    socket.inbound = yes
    if false is socket.peer = Peer.fromSocket socket._socket
      console.error fail ' REJECT-WSS - Invalid- or non-IRAC certificate '
      return socket.close()
    Request.acceptSocket socket

###
  REQUEST
###

$static Request: (peer,args,callback) ->
  { irac } = peer
  { queue, active } = Request
  a = active[irac] = active[irac] || active[irac] = []
  q = queue[irac]  = queue[irac]  || queue[irac]  = []
  q.push arguments
  a.counter = 0 unless a.counter?
  if Request.connected[irac]
    clearTimeout Request.queue.dirty
    Request.queue.dirty = setImmediate ->
      Request.flush peer
  else Request.connect peer

Request.WebSocket = require 'ws'

Request.queue      = {}
Request.active     = {}
Request.connecting = {}
Request.connected  = {}

Request.flush = (peer)->
  return ( console.error 'REQUEST-NO-SOCKET'; false ) unless socket = Request.connected[irac = peer.irac]
  return ( console.error 'REQUEST-NO-QUEUE';  false ) unless queue  = Request.queue[irac]
  return ( console.error 'REQUEST-NO-ACTIVE'; false ) unless active = Request.active[irac]
  for request in queue
    request.uid = uid = ++active.counter
    socket.send [REQUEST,uid,request[1]]
    active.push request
    # console.hardcore 'REQUEST-REPLAY', irac, uid, request[1]
  Request.queue[irac] = []
  true

Request.Agent = (opts) ->
  https.Agent.call @, opts
  @protocol = 'https:'
  @createConnection = (opts) ->
    host = opts.host
    _error = (stage)-> (error)-> console.hardcore ' SOCKSJS '.red.bold.inverse, opts.host, 'error:' + stage, error
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
  opts.key = $config.hostid.pem
  opts.ca = if peer.cachain then peer.cachain else $config.hostid.cachain
  opts.cert = peer.cert || $config.hostid.cert
  if peer.address
    if peer.irac then opts.url = protocol + '://' + peer.irac    + ':2003/rpc/'
    else              opts.url = protocol + '://' + peer.address + ':2003/rpc/'
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
    return Request.retry 10000, req if msg is 'SOCKS: Host unreachable'
    return Request.retry 10000, req if msg is 'SOCKS: TTL expired'
    return Request.retry 60000, req if msg.match /^SOCKS/
    return Request.retry 5000,  req if msg.code is 'ECONNREFUSED'
    if msg.code is 'ENOTFOUND' and peer.address
      delete peer.address
      return Request.retry 0, req
    console.error " REQUEST-ERROR ".red.bold.inverse, arguments[0]
  null

Request.pipe = (peer,args,target,callback) ->
  opts = Request.tlsOpts peer, 'https'
  opts.url += args.map(encodeURIComponent).join('/')
  $request.get(opts).pipe(target)
  null

Request.connect = (peer) -> do req = ->
  return ( peer.debug  ' WSC-ALREADY-CONNECTED '.green.bold.inverse; true ) if Request.connected[irac = peer.irac]
  return ( peer.debug  ' WSC-ALREADY-CONNECTING '.red.bold.inverse; false ) if Request.connecting[irac]
  session = {}; opts = Request.tlsOpts peer, 'wss'
  # console.hardcore 'WSC-CONNECTING', opts.url
  socket = new Request.WebSocket opts.url, opts
  socket.on 'open', ->
    socket.peer = Peer.fromSocket socket._socket.outSocket || socket._socket
    socket.removeListener 'error', connect_error
    Request.acceptSocket socket if socket.peer.irac is peer.irac
    null
  socket.on 'error', connect_error = (error)->
    return                          if Request.connected[irac]
    delete Request.connecting[irac] if Request.connecting[irac] is socket
    return Request.retry 10000, req if error      is 'SOCKS: Host unreachable'
    return Request.retry 10000, req if error      is 'SOCKS: TTL expired'
    return Request.retry 5000,  req if error.code is 'ECONNREFUSED'
    if error.code is 'ENOTFOUND' and peer.address
      console.debug Peer.format(peer).inverse, ' WSC-DISABLE-DIRECT '.yellow.bold.inverse
      delete peer.address
      return Request.retry 0, req
    console.error Peer.format(peer), ' WSC-CONNECT-ERROR '.red.bold.inverse, error
    delete Request.connecting[irac]
    null
  true

ERROR = -1; REQUEST = 0; RESPONSE = 1

Request.acceptSocket = (socket)->
  unregister = ->
    delete Request.connecting[irac] if socket is Request.connecting[irac]
    delete Request.connected[irac]  if socket is Request.connected[irac]
  close = (error)->
    peer.debug  ' WS-CLOSE '.blue.bold.inverse, error
    peer.lastSeen = Date.now()
    do unregister
    Message.peerLost peer
    return if irac is $config.hostid.irac
    Request.connect peer
    null
  fail = (message,data)->
    socket.close(); do unregister
    console.error Peer.format(peer||{}), message.red.bold.inverse, data; false
  return fail ' REQUEST-NO-PEER ' unless ( peer = socket.peer )?
  return fail ' REQUEST-NO-IRAC ' unless ( irac = peer.irac )?
  if ( s = Request.connected[irac] ) and s isnt socket
    return fail ' WSC-DOUBLE '
  peer.hardcore ' WS-ACCEPT '.green.bold.inverse

  delete Request.connecting[irac] if Request.connecting[irac] is socket
  Request.connected[peer.irac] = socket
  peer.lastSeen = Date.now()
  Message.peer peer
  _send = socket.send.bind socket

  socket.send = (data)->
    try _send $cbor.encode(data,no,yes,no), binary:on, mask:off
    catch error
      socket.emit 'close', error
      fail ' WS-SEND-ERROR ', error

  socket.fail = (error,data)->
    peer.error error, $util.inspect data
    socket.send [ -1, -1, [ error + "\n" + data ] ]

  socket.on "message", (m)->
    try m = $cbor.decode m
    catch e then return peer.error ' WS-INVALID-BSON '.red.bold.inverse, $util.inspect m
    # peer.hardcore  'WS-MESSAGE', $util.inspect m

    return socket.fail Peer.format(peer), ' WS-NOT-AN-ARRAY '.red.bold.inverse, m unless Array.isArray m

    [ msgType, uid, msg ] = m
    return socket.fail Peer.format(peer), ' WS-INVALID-STRUCTURE '.red.bold.inverse, m unless msgType? and uid? and msg? and msg.push?

    if msgType is REQUEST
      # console.hardcore 'WS-RPC', uid, msg
      rpc = new $rpc.scope ws:socket, group:socket.peer.group, peer:peer, cmd:msg, reply: (args...)->
        socket.send [RESPONSE,uid,args]

    else if ( msgType is RESPONSE ) and ( queue = Request.active[irac] )?
      for request in queue.slice() when request.uid is uid
        if typeof ( callback = request[2] ) is 'function'
          # peer.hardcore  ' WS-RESPONSE '.green.bold.inverse, uid, $util.inspect msg
          callback.apply null, [null].concat msg
        Array.remove queue, request
        break

    else if msgType is ERROR
      peer.error ' WS-REMOTE-ERROR '.red.bold.inverse, msg.join '\n  '

    else peer.error ' WS-ILLEGAL '.red.bold.inverse, msgType, uid, msg
    null

  socket.on 'error', (error)->
    peer.error ' WS-ERROR '.red.bold.inverse, error
    null

  socket.on 'close', close

  Request.flush peer
  null
