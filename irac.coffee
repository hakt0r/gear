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
  @npm 'socksjs git+https://github.com/hakt0r/socksjs', 'cbor-sync', 'mime', 'serve-static'

$static IRAC:{}
$static PEER: $config.peers || $config.peers = {}

PEER[$config.hostid.irac] = $config.hostid
$config.hostid.direct = true

socksjs = require 'socksjs'
https   = require 'https'
cbor    = require 'cbor-sync'

$static Peer: {}

Peer.Agent = (opts) ->
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

$util.inherits Peer.Agent, https.Agent

Peer.tlsOpts = (peer,protocol)->
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
  opts.agent = new Peer.Agent opts
  opts

Peer.retry = $function
  block: -> Peer.retry.status = 'closed'
  unblock: ->
    Peer.retry.status = 'open'
    (Peer.retry.hold || []).map (callback)-> do callback
    Peer.retry.hold = []
  (timeout,callback)-> setTimeout ( ->
      if Peer.retry.status is 'closed'
        Peer.retry.hold.push callback
      else do callback
    ), timeout
do Peer.retry.unblock

Peer.request = (peer,args,callback) ->
  { irac } = peer
  { request } = Peer
  { queue, active } = request
  a = active[irac] = active[irac] || active[irac] = []
  q = queue[irac]  = queue[irac]  || queue[irac]  = []
  q.push arguments
  a.counter = 0 unless a.counter?
  if Peer.request.socket[irac]
    clearTimeout Peer.request.queue.dirty
    Peer.request.queue.dirty = setImmediate ->
      Peer.request.flush peer
  else Peer.request.connect peer

Peer.request.queue      = {}
Peer.request.active     = {}
Peer.request.socket     = {}
Peer.request.connecting = {}
Peer.request.connected  = {}

$app.on 'web:listening', -> $web.wss.on "connection", (socket)->
  $auth.verify socket, socket._socket, true
  Peer.acceptSocket socket
  null

Peer.WebSocket = require 'ws'
Peer.request.connect = (peer) -> do req = ->
  return ( console.debug 'IRAC-WSC-ALREADY-CONNECTED';  true  ) if Peer.request.socket[irac = peer.irac]
  return ( console.debug 'IRAC-WSC-ALREADY-CONNECTING'; false ) if Peer.request.connecting[irac]
  session = {}; opts = Peer.tlsOpts peer, 'wss'
  # console.hardcore 'IRAC-WSC-CONNECTING', opts.url
  socket = new Peer.WebSocket opts.url, opts
  socket.on 'open', ->
    $auth.verify socket, socket._socket
    if Peer.request.socket[irac]
      console.debug 'IRAC-WSC-DOUBLE', irac
      return socket.close()
    # console.debug 'IRAC-WSC-CONNECT', irac
    socket.removeListener 'error', connect_error
    Peer.acceptSocket socket, peer
    null
  socket.on 'error', connect_error = (error)->
    return Peer.retry 10000, req if error      is 'SOCKS: Host unreachable'
    return Peer.retry 10000, req if error      is 'SOCKS: TTL expired'
    return Peer.retry 5000,  req if error.code is 'ECONNREFUSED'
    console.error 'IRAC-WSC-CONNECT-ERROR', peer.irac, error
    delete Peer.request.connecting[irac]
    null
  true

ERROR = -1; REQUEST = 0; RESPONSE = 1
Peer.acceptSocket = (socket,peer)->
  unless socket.irac is $config.hostid.irac
    ( console.error 'IRAC-REQUEST-NO-PEER';  return false ) unless ( peer = peer || PEER[socket.cert.irac] )
    ( console.debug 'IRAC-WS-ALREADY-CONNECTED'; return false ) if Peer.request.socket[peer.irac]
  else peer = $config.hostid
  console.hardcore 'IRAC-WS-ACCEPT', peer.irac

  delete Peer.request.connecting[irac]
  Peer.request.socket[irac = peer.irac] = socket
  Peer.request.connected[irac] = peer
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

    else if ( msgType is RESPONSE ) and ( queue = Peer.request.active[irac] )?
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
    delete Peer.request.socket[irac]
    delete Peer.request.connecting[irac]
    delete Peer.request.connected[irac]
    peer.lastSeen = Date.now()
    Channel.byName.peer.pull peer
    return if irac is $config.hostid.irac
    Peer.request.connect peer
    null

  Peer.request.flush peer
  null

Peer.request.flush = (peer)->
  return ( console.error 'IRAC-REQUEST-NO-SOCKET'; false ) unless socket = Peer.request.socket[irac = peer.irac]
  return ( console.error 'IRAC-REQUEST-NO-QUEUE';  false ) unless queue  = Peer.request.queue[irac]
  return ( console.error 'IRAC-REQUEST-NO-ACTIVE'; false ) unless active = Peer.request.active[irac]
  for request in queue
    request.uid = uid = ++active.counter
    socket.send [REQUEST,uid,request[1]]
    active.push request
    # console.hardcore 'IRAC-REQUEST-REPLAY', irac, uid, request[1]
  Peer.request.queue[irac] = []
  true

Peer.request.static = (peer,args,callback) ->
  opts = Peer.tlsOpts peer, 'https'
  opts.rejectUnauthorized = no
  opts.method = 'POST'
  opts.body = args
  opts.json = true
  # console.hardcore 'REQUEST'.green.inverse, peer, args[0]
  do req = -> $request( opts, (e)-> callback.apply null, arguments unless e ).on 'error', (msg)->
    return Peer.retry 10000, req if msg      is 'SOCKS: Host unreachable'
    return Peer.retry 10000, req if msg      is 'SOCKS: TTL expired'
    return Peer.retry 5000,  req if msg.code is 'ECONNREFUSED'
    console.log "IRAC-REQUEST-ERROR", arguments[0]
  null

Peer.request.pipe = (peer,args,target,callback) ->
  opts = Peer.tlsOpts peer, 'https'
  opts.url += args.map(encodeURIComponent).join('/')
  $request.get(opts).pipe(target)
  null

Peer.subscribe = (peer,list)->
  sub = peer.sub || peer.sub = []; uniq = {}
  peer.sub = sub = sub.concat(list).filter (i)->
    return false if uniq[i]; uniq[i] = yes

Peer.opts = (peer) -> {
  head: Channel.update
  sync: peer.remoteHead || peer.remoteHead = 0
  subscribe: Object.keys(Channel.byName) }
Peer.optsHash = (peer) -> IRAC.hash Peer.opts peer

Peer.readOpts = (peer,msg) ->
  return null unless msg and msg.opts
  opts = msg.opts; delete msg.opts
  Peer.subscribe peer, opts.subscribe if opts.subscribe?
  peer.remoteHead = opts.head         if opts.head?
  peer.remoteSync = opts.sync         if opts.sync?
  opts



Peer.probe = (peer) -> if peer.cert? and ( typeof peer.cert is 'string' ) and peer.onion?
  # console.debug ' PROBE '.yellow.inverse.bold, peer
  Peer.sync peer
  null

Peer.probe.all = ->
  Peer.probe peer for k,peer of PEER when peer.irac isnt $config.hostid.irac
  null


Peer.sync = (peer,callback)-> want = offer = null; $async.series [
  (c)->
    console.log 'IRAC-SYNCING-WITH', peer.irac, peer.remoteHead
    Peer.request peer, [
      'irac_sync', opts: Peer.opts peer
    ], (error,request,msg)->
      unless error
        console.hardcore 'SYNC-REPLY', peer.irac, msg
        Peer.readOpts peer, msg
        offer = Channel.sync    peer, peer.remoteSync
        want  = Channel.compare peer, msg
        console.hardcore 'SYNC-WANT', peer.irac, want
      c error
  (c)-> Peer.get peer, want, offer, c
  -> do callback if callback ]

$command irac_sync: $group '$peer', (msg)->
  return false unless peer = PEER[irac = $$.cert.irac]
  console.log 'IRAC-SYNC', peer.irac, msg
  Peer.readOpts peer, msg
  o = Channel.sync peer, peer.remoteSync
  o.opts = Peer.opts peer
  o


Peer.get = (peer,want,offer,callback)->
  c = 0
  c += Object.keys(want).length  if want
  c += Object.keys(offer).length if offer
  if 0 is c
    do callback if callback
    return false
  Peer.request peer, ['irac_trade',want,offer], (error,request,result)->
    console.hardcore 'SYNC-GOT', peer.irac, result
    Channel.push peer, result unless error
    callback error, request, result if callback
  true

Peer.getBlob = (peer,hash)->
  return if $fs.existsSync link = $path.sharedHash hash
  return if $config.hostid.irac is peer.irac
  console.log ' IRAC-GET-BLOB '.yellow.inverse.bold, hash
  Peer.request.pipe peer, ['irac_get',hash], $fs.createWriteStream link

$command irac_trade: $group '$peer', (want,offer,remoteHead)->
  return false unless peer = PEER[irac = $$.cert.irac]
  console.log 'IRAC-TRADE', irac, want, offer
  Peer.get peer, Channel.compare(peer,offer) if offer?
  peer.remoteHead = remoteHead               if remoteHead?
  return Channel.get peer, want              if want?
  null

$command irac_getall: (channel)->
  Channel.resolve(channel,no).list.map (i)->
    i.item

class SyncQueue
  @byIRAC: {}
  @distribute = (source,channel,items)->
    queue  = SyncQueue.byIRAC
    source = irac: $config.hostid.onion unless source
    hashed = items.map IRAC.hash
    connected = Peer.request.connected
    for irac, peer of connected when irac isnt source.irac or irac is $config.hostid.irac
      q = queue[irac] = queue[irac] || {}
      q[channel] = ( q[channel] = [] ).concat if peer.direct then items else hashed
    @publish()
  @publish: $async.pushup deadline:100, threshold:100, worker: (cue, done)->
    for irac, channels of SyncQueue.byIRAC
      continue unless peer = PEER[irac]
      console.hardcore 'IRAC-PUSHING', irac, channels
      Peer.request peer, ['irac_trade',null,channels,Channel.update], ->
        console.hardcore 'IRAC-PUSHED', irac, channels
      SyncQueue.byIRAC[irac] = {}
    done null

$app.on 'daemon', -> do Peer.probe.all








$static class Channel
  list: null
  update: null
  constructor:(opts)->
    Object.assign @, opts
    @list = @list || []
    @byHash = {}
    Channel.byName[@name] = @
    for item in @list
      @update = Math.max item.date, @update
      @byHash[item.hash] = item
    Channel.update = Math.max @update, Channel.update || 0
    # console.log " NEW CHANNEL ".red, @name, @list.length, @update, Channel.update
    do $app.sync
  sync:(date)-> i.hash for i in @list when i.date > date
  push:(source,items...)->
    out = []
    for item in items when not @byHash[hash = IRAC.hash item]
      switch r = $auth.verifyMessage item
        when true
          out.push item
          @list.unshift @byHash[hash] = date:( Channel.update = @update = d = do Date.now ), item:item, hash:hash
          Peer.getBlob source, item.hash if item.hash
        else console.error ' NO-PUSH '.red.bold.inverse, r
    $app.sync 'channel', @name, out
    SyncQueue.distribute source, @name, out
    @updated
  toBSON:=> name:@name, list:@list

Channel.update = 0

Channel.resolve = (name)-> Channel.byName[name] || new Channel name:name

Channel.init = ->
  Channel.byName = $config.channels || $config.channels = {}
  for name, opts of @byName
    opts.name = name
    new Channel opts
  # Channel.byName.test.list = [] if Channel.byName.test

Channel.sync = (peer,date)->
  response = {}
  for c in peer.sub when ch = @byName[c]
    response[c] = ch.sync(date)
    delete response[c] if response[c].length is 0
  response

Channel.compare = (peer,channels)->
  for name, list of channels when channel = @byName[name]
    channels[name] = list.filter( (i)-> not channel.byHash[i]? )
    delete channels[name] if channels[name].length is 0
  channels

Channel.push = (source,channels)->
  for name,list of channels when channel = @byName[name]
    channel.push.apply channel, [source].concat list
  null

Channel.get = (peer,channels)->
  channels.opts = Peer.opts peer if channels.opts?
  for name,list of channels
    if ( channel = @byName[name] )
      channels[name] = ( item.item for hash in list when item = channel.byHash[hash] )
    else delete channels[name]
  channels

do Channel.init

$static class LivePeer
  constructor:(opts)->
    @list = @list || []
    @byHash = {}
  sync: -> @list.map (i)-> i.irac
  pull: (peer)->
    Array.remove @list, peer
    delete @byHash[peer.irac]
  push: (peer)-> unless @byHash[peer.irac]
    @list.push item: item = @byHash[peer.irac] = from:peer.irac, date: peer.lastSeen || 0
    SyncQueue.distribute null, 'peer', [item]

Channel.byName.peer = new LivePeer





$command peer: (address)->
  return 'ENOPEER' unless address
  Peer.request.static { address:address, local:yes }, [
    'irac_peer', $config.hostid.irac, $config.hostid.onion, $config.hostid.cachain, $auth.request()
  ], (error,req,body)->
    return console.log error if error
  'calling_' + address

Peer.defaultGroups = (peer)->
  peer.group = Array.unique ( peer.group || [] ).concat ['$peer']

$command irac_peer: $group '$public', (irac,onion,ca,csr,ack)->
  return no  if PEER[irac] and $$.cert.irac isnt irac
  return yes if PEER[irac] and PEER[irac].local and PEER[irac].remote
  if ack?
    PEER[irac] = peer = irac:irac, onion:onion, ca:ca, cert:ack, remote: hisCert = $auth.authorize(csr)
    Peer.defaultGroups peer
    console.log ' PEERED-WITH '.blue.bold.inverse, irac
    setTimeout ( -> Peer.sync peer, (error)-> ), 1000 # TODO: distrust on error
    PEER[irac].cert = ack
    return hisCert
  # return no if PEER[irac]?
  PEER[irac] = peer = irac:irac, onion:onion, ca:ca, cert:no, remote: hisCert = $auth.authorize(csr)
  Peer.defaultGroups peer
  Peer.request.static peer, [
    'irac_peer', $config.hostid.irac, $config.hostid.onion, $config.hostid.cachain, $auth.request(), hisCert
  ], (error,req,myCert)->
    return console.error error if error
    console.log ' PEERED-WITH '.green.bold.inverse, irac
    peer.cert = myCert
    Peer.sync peer, (error)-> # TODO: distrust on error
    null
  'calling_back'





$path.shared = $path.join $path.configDir, 'shared'
$path.sharedHash = (hash) -> $path.join $path.shared, hash
$fs.mkdirSync $path.shared unless $fs.existsSync $path.shared

$app.on 'web:listening', ->
  $web.static = require('serve-static')($path.shared)

$command share: (channel,file)->
  return false unless $fs.existsSync file
  hash = null; i = $cp.spawn 'sha1sum', [file]
  console.log ' HASHING ', file
  i.stdout.on 'data', (d)-> hash = d.toString().replace(/ .*/, '').trim()
  i.on 'close', (status,signal)->
    console.log status, hash
    if status is 0
      mime = require 'mime'
      console.log 'share', file, hash
      link = $path.sharedHash hash
      $fs.symlinkSync file, link unless $fs.existsSync link
      Channel.resolve(channel).push null, $auth.signMessage
        type: mime.lookup file
        body: "File: " + $path.basename file
        size: $fs.statSync(file).size
        hash: hash
  true

$command irac_get: $group '$peer', (msg)->
  console.log 'get', msg
  mime = require 'mime'
  try file = $fs.realpathSync link = $path.sharedHash msg catch e then file = null
  if $$.web
    { req, res, next } = $$.web; $$.pipe = on
    if file and $fs.existsSync link
      console.log ' REQ '.whiteBG.black.bold, req.url = req.url.replace /rpc\/irac_get\//, ''
      $web.static req, res, next
    else
      res.status 504
      res.end 'Resource temporarily unavailable'
  else if $fs.existsSync link
    $fs.readFileSync link
  else false






IRAC.hash = (item)-> $md5 JSON.stringify item

$command list: (channel)->
  Object.keys Channel.byName

$command show: (channel)->
  Channel.resolve(channel,no).list.map (i)->
    i = i.item
    i.from.substr(0,5) + ": " + i.body

$command say: (channel,message...)->
  msg = $auth.signMessage type:'text/utf8', body: message.join ' '
  Channel.resolve(channel).push null, msg

$command subscribe: (channel)->
  Channel.resolve channel
  do $app.sync
  true

$command unsubscribe: (channel)->
  delete Channel.byName[channel]
  do $app.sync
  true

$command sync: (irac)->
  peer = PEER[irac] if irac
  Peer.sync peer
  true
