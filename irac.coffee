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
  @npm 'mime', 'serve-static'
  @mod 'auth'

Peer.defaultGroups = (peer)->
  peer.group = Array.unique ( peer.group || [] ).concat ['$peer']

Peer.subscribe = (peer,list)->
  sub = peer.sub || peer.sub = []; uniq = {}
  peer.sub = sub = sub.concat(list,['@'+peer.root,'@'+peer.irac]).filter (i)->
    return false if (not i?) or i is 'null'
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

Peer.probe = (peer) ->
  console.debug Peer.format(peer), ' PROBE '.yellow.inverse.bold
  Peer.sync peer
  null

Peer.probe.all = ->
  for k,peer of PEER
    console.log k
    if k isnt $config.hostid.irac
      Peer.probe peer
  null

Peer.sync = (peer,callback)-> want = offer = null; $async.series [
  (c)->
    console.log Peer.format(peer), 'IRAC-SYNCING-WITH', peer.remoteHead
    Request peer, [
      'irac_sync', opts: Peer.opts peer
    ], (error,request,msg)->
      unless error
        console.hardcore Peer.format(peer), 'SYNC-REPLY', msg
        Peer.readOpts peer, msg
        offer = Channel.offer   peer, peer.remoteSync
        want  = Channel.compare peer, msg
        console.hardcore Peer.format(peer), 'SYNC-WANT', want if Object.keys(want).length > 0
      c error
  (c)-> Peer.trade peer, want, offer, c
  -> do callback if callback ]

Peer.trade_filter = (map)->
  _.omit map, (val,key)-> not ( Array.isArray(val) and val.length > 0 )

Peer.trade = (peer,want,offer,callback)->
  c = 0
  ( want = Peer.trade_filter want; c += Object.keys(want).length )    if want
  ( offer = Peer.trade_filter offer; c += Object.keys(offer).length ) if offer
  if 0 is c
    do callback if callback
    return false
  Request peer, ['irac_trade',want,offer], (error,result)->
    console.hardcore Peer.format(peer), 'SYNC-TRADE-RESULT', result
    Channel.push peer, result unless error
    callback error, result if callback
  true

Peer.getBlob = (peer,hash)->
  return if $fs.existsSync link = $path.sharedHash hash
  return if $config.hostid.irac is peer.irac
  console.log ' IRAC-GET-BLOB '.yellow.inverse.bold, hash
  Request.pipe peer, ['irac_get',hash], $fs.createWriteStream link







class SyncQueue
  @byIRAC: {}
  @distribute = (source,channel,items)->
    return unless channel?
    source = $config.hostid unless source?
    queue  = SyncQueue.byIRAC
    hashed = items.map Channel.hash
    connected = Request.connected
    for irac, peer of connected when irac isnt source.irac or irac is $config.hostid.irac
      q = queue[irac] = queue[irac] || {}
      q[channel] = ( q[channel] = [] ).concat if peer.direct or channel[0] is '@' then items else hashed
    @publish()
  @publish: $async.pushup deadline:100, threshold:100, worker: (cue, done)->
    for irac, channels of SyncQueue.byIRAC
      continue unless peer = PEER[irac]
      continue unless 0 < Object.keys( channels = Peer.trade_filter channels ).length
      console.hardcore Peer.format(peer), 'IRAC-PUSHING', channels
      Peer.trade peer, null, channels, ->
        console.hardcore Peer.format(peer), 'IRAC-PUSHED', channels
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
    console.log ' NEW CHANNEL '.red, @name, @list.length, @update, Channel.update
    do $app.sync
  collect:(peer,date)-> i.hash for i in @list when i.date > date
  push:(peer,items...)->
    out = []
    for item in items when not @byHash[hash = Channel.hash item]
      switch r = $auth.verifyMessage item
        when true
          out.push item
          @list.unshift @byHash[hash] = date:( Channel.update = @update = d = do Date.now ), item:item, hash:hash
          Peer.getBlob peer, item.hash if item.hash
        else console.error ' NO-PUSH '.red.bold.inverse, r
    $app.sync 'channel', @name, out
    SyncQueue.distribute peer, @name, out
    @updated
  toBSON:=> name:@name, list:@list

Channel.update = 0

Channel.hash = (item)->
  $md5 JSON.stringify item

Channel.resolve = (channel,create=true)->
  exists = Channel.byName[name = channel.name || channel]
  return false if not ( create or exists? )
  ( Channel.remove name; return false ) if name.match ' '
  result = Channel.byName[name] || new ( if name[0] is '@' then PMSGQueue else Channel )(
    if typeof channel is 'object' then channel else name )
  # console.hardcore ' CHANNEL-RESOLVE ', name, exists?, create, result::
  result

Channel.remove = (name)->
  delete Channel.byName[name]
  # TODO: hook for $sub channel

Channel.init = ->
  Channel.byName = $config.channels || $config.channels = {}
  for name, opts of Channel.byName
    opts.name = name
    ctor = if name[0] is '@' then PMSGQueue else Channel
    console.log ctor, name
    new ctor opts
  $config.channels = Channel.byName
  null

Channel.offer = (peer,date)->
  response = {}
  for c in Peer.subscribe(peer) when ( ch = Channel.resolve(c,no) )
    response[c] = ch.collect(peer,date)
    delete response[c] if response[c].length is 0
  response

Channel.compare = (peer,channels)->
  for name, list of channels when channel = Channel.resolve(name,no)
    if typeof list[0] isnt 'string'
      Channel.resolve(name).push channels[name]
      channels[name] = []
    else channels[name] = list.filter( (i)-> not channel.byHash[i]? )
    delete channels[name] if channels[name].length is 0
  channels

Channel.push = (source,channels)->
  for name,list of channels when channel = Channel.resolve(name,no)
    channel.push.apply channel, [source].concat list
  null

Channel.get = (peer,channels)->
  channels.opts = Peer.opts peer if channels.opts?
  for name,list of channels
    if ( channel = Channel.resolve(name,no) )
      channels[name] = ( item.item for hash in list when item = channel.byHash[hash] )
    else delete channels[name]
  channels

$static class PMSGQueue extends Channel
  constructor:(opts)-> super opts
  collect: (peer)-> @list


do Channel.init

Channel.resolve('status')
Channel.resolve('peer')
Channel.resolve('@'+$config.hostid.root)
Channel.resolve('@'+$config.hostid.irac)
Channel.remove()
Channel.remove(null)
Channel.remove('null')
Channel.remove('undefined')


$static class LivePeer
  name: 'peer'
  constructor:->
    @list = @list || []
    @byHash = {}
  collect: -> @list.map (i)-> i.irac
  pull: (peer)->
    Array.remove @list, peer
    delete @byHash[peer.irac]
  push: (peer)-> unless @byHash[peer.irac]
    @list.push item: item = @byHash[peer.irac] = caname:peer.caname, name:peer.name, root:peer.root, from:peer.irac, date: peer.lastSeen || 0
    SyncQueue.distribute null, 'peer', [item]

Channel.byName.peer = new LivePeer







$command irac_peer: $group '$public', (ca,ack)->
  $$.peer.parseCertificate $$.peer.pem, ca
  { irac, root, onion, ia } = peer = $$.peer
  if ack?
    return yes if peer and peer.remote
    Object.assign peer, cert:ack, remote:hisCert = $auth.authorize peer
    console.log Peer.format(peer), ' PEERED-WITH '.blue.bold.inverse, peer
    setTimeout ( -> Peer.sync peer, (error)-> ), 1000 # TODO: distrust on error
    peer.groups '$peer'
    do $app.sync
    return hisCert
  # return no if PEER[irac]?
  Object.assign cert:no, remote: hisCert = $auth.authorize peer
  Request.static peer, [
    'irac_peer', $config.hostid.cachain, hisCert
  ], (error,req,myCert)->
    return console.error error if error
    console.log Peer.format(peer), ' PEERED-WITH '.green.bold.inverse, peer
    peer.groups '$peer'
    peer.cert = myCert
    Peer.sync peer, (error)-> # TODO: distrust on error
    do $app.sync
    null
  'calling_back'

$command irac_sync: $group '$peer', (msg)->
  return false unless peer = $$.peer
  console.log Peer.format(peer), 'IRAC-SYNC', msg
  Peer.readOpts peer, msg
  o = Channel.offer peer, peer.remoteSync
  o.opts = Peer.opts peer
  o

$command irac_trade: $group '$peer', (want,offer,remoteHead)->
  return false unless peer = $$.peer
  peer.remoteHead = remoteHead if remoteHead?
  if offer? and Object.keys(offer).length > 0
    console.debug Peer.format(peer), ' OFFERS '.yellow.bold.inverse, offer
    Peer.trade peer, Channel.compare(peer,offer)
  if want? and Object.keys(want).length > 0
    console.debug Peer.format(peer), ' WANTS '.yellow.bold.inverse, want
    return Channel.get peer, want
  true

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






$command peer: Peer.requestAuth = (address)->
  return 'ENOPEER' unless address
  Request.static address:address, [
    'irac_peer', $config.hostid.cachain
  ], (error,req,body)->
    return console.error error if error
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

$command set: (id,key,value)->
  item = Peer.byCA[id.substr(1)]          if id[0] is '@'
  item = PEER[id.substr(1)]               if id[0] is '@' and not item?
  item = Channel.resolve(id.substr(1),no) if id[0] is '#'
  item = Channel.resolve(id,          no) unless item
  return false unless item
  for i in ( items = if item.list then item.list else [item] )
    i[key] = value
    console.log 'set', id, Peer.format(i), key, value
  do $app.sync
  true

$command say: (channel,message...)->
  msg = $auth.signMessage type:'text/utf8', body: message.join ' '
  Channel.resolve(channel).push null, msg
  true

$command subscribe: (channel)->
  Channel.resolve channel
  do $app.sync
  true

$command unsubscribe: (channel)->
  Channel.remove channel
  do $app.sync
  true

$command sync: (irac)->
  peer = PEER[irac] if irac
  Peer.sync peer
  true

$command ssh_empeer: process.cli.ssh_empeer = (host)->
  hostname = $md5 host; peer = null
  $async.series [
    (c)=> $cp.exec """ssh #{host} hostname""", => do c
    (c)=> c null, peer = $auth.setupKeys $md5 host
    (c)=> $cp.exec """
      cd #{$path.configDir} &&
      tar cjvf - ca/ca.pem ca/intermediate_ca.pem ca/#{hostname}* modules/* |
      ssh #{host} 'cd ; cat - > .peer_setup.tbz'
    """, => do c
    (c)=> $cp.ssh( host, """
      [ -f .peer_setup.tbz ] || exit 1
      cd; rm -rf .config/gear/modules .config/gear/ca
      cd .config/gear/ && tar xjvf ../../.peer_setup.tbz &&
      cd && rm .peer_setup.tbz
      cd .config/gear/ca; rm -f me*; rename 's/#{hostname}/me/' *
      cd; touch  .config/gear/ca/ca_outlet
      cd; coffee .config/gear/modules/gear.coffee install
    """ ); setTimeout (-> do c), 3000
    (c)=>
      delete peer.cert; delete peer.key; delete peer.pem
      Peer.sync new Peer peer, name:host, group:['$host'], address:host
      null ]
