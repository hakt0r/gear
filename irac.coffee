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

return unless $require -> @npm 'mime', 'serve-static'

$static PEER: $config.peers || $config.peers = {}

PEER[$config.hostid.irac] = $config.hostid
$config.hostid.direct = true

$static Peer: (irac)-> PEER[irac] || irac:irac

Peer.defaultGroups = (peer)->
  peer.group = Array.unique ( peer.group || [] ).concat ['$peer']

Peer.subscribe = (peer,list)->
  sub = peer.sub || peer.sub = []; uniq = {}
  peer.sub = sub = sub.concat(list).filter (i)->
    return false if uniq[i]; uniq[i] = yes

Peer.opts = (peer) -> {
  head: Channel.update
  sync: peer.remoteHead || peer.remoteHead = 0
  subscribe: Object.keys(Channel.byName) }
Peer.optsHash = (peer) -> Channel.hash Peer.opts peer

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
    Request peer, [
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

Peer.get = (peer,want,offer,callback)->
  c = 0
  c += Object.keys(want).length  if want
  c += Object.keys(offer).length if offer
  if 0 is c
    do callback if callback
    return false
  Request peer, ['irac_trade',want,offer], (error,request,result)->
    console.hardcore 'SYNC-GOT', peer.irac, result
    Channel.push peer, result unless error
    callback error, request, result if callback
  true

Peer.getBlob = (peer,hash)->
  return if $fs.existsSync link = $path.sharedHash hash
  return if $config.hostid.irac is peer.irac
  console.log ' IRAC-GET-BLOB '.yellow.inverse.bold, hash
  Request.pipe peer, ['irac_get',hash], $fs.createWriteStream link







class SyncQueue
  @byIRAC: {}
  @distribute = (source,channel,items)->
    queue  = SyncQueue.byIRAC
    source = irac: $config.hostid.onion unless source
    hashed = items.map Channel.hash
    connected = Request.connected
    for irac, peer of connected when irac isnt source.irac or irac is $config.hostid.irac
      q = queue[irac] = queue[irac] || {}
      q[channel] = ( q[channel] = [] ).concat if peer.direct then items else hashed
    @publish()
  @publish: $async.pushup deadline:100, threshold:100, worker: (cue, done)->
    for irac, channels of SyncQueue.byIRAC
      continue unless peer = PEER[irac]
      console.hardcore 'IRAC-PUSHING', irac, channels
      Request peer, ['irac_trade',null,channels,Channel.update], ->
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
    for item in items when not @byHash[hash = Channel.hash item]
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

Channel.hash = (item)->
  $md5 JSON.stringify item

Channel.resolve = (name)->
  Channel.byName[name] || new Channel name:name

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
  Request.static peer, [
    'irac_peer', $config.hostid.irac, $config.hostid.onion, $config.hostid.cachain, $auth.request(), hisCert
  ], (error,req,myCert)->
    return console.error error if error
    console.log ' PEERED-WITH '.green.bold.inverse, irac
    peer.cert = myCert
    Peer.sync peer, (error)-> # TODO: distrust on error
    null
  'calling_back'

$command irac_sync: $group '$peer', (msg)->
  return false unless peer = PEER[irac = $$.cert.irac]
  console.log 'IRAC-SYNC', peer.irac, msg
  Peer.readOpts peer, msg
  o = Channel.sync peer, peer.remoteSync
  o.opts = Peer.opts peer
  o

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






$command peer: (address)->
  return 'ENOPEER' unless address
  Request.static { address:address, local:yes }, [
    'irac_peer', $config.hostid.irac, $config.hostid.onion, $config.hostid.cachain, $auth.request()
  ], (error,req,body)->
    return console.log error if error
  'calling_' + address

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
