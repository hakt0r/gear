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

###
  CHANNEL
###

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
    # console.log ' NEW CHANNEL '.red, @name, @list.length, @update, Channel.update
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
        else console.error ' NO-PUSH '.red.bold.inverse, r, item
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
    if typeof channel is 'object' then channel else name:channel )
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
    new ctor opts
  $config.channels = Channel.byName
  Channel.resolve('$status')
  Channel.resolve('@'+$config.hostid.ra)
  Channel.resolve('@'+$config.hostid.irac)
  Channel.remove()
  Channel.remove(null)
  Channel.remove('null')
  Channel.remove('peer')
  Channel.remove('status')
  Channel.remove('undefined')
  Channel.byName.$peer = new LivePeer
  null

Channel.push = (source,channels)->
  for name,list of channels when channel = Channel.resolve(name,no)
    channel.push.apply channel, [source].concat list
  null

$static class PMSGQueue extends Channel
  constructor:(opts)-> super opts
  collect: (peer)-> @list.map (i)-> i.item

Peer.filter = (peer,i)->
  return false unless peer? and i? and ACL.check peer, '$local', '$host', '$peer'
  return i if typeof i is 'string'
  return false if ( i.irac is peer.irac ) or ( i.irac is $config.hostid.irac )
  onion:i.onion, irac:i.irac, ra:i.ra, ia:i.ia

Peer.filterList = (peer,list)->
  list.map(Peer.filter.bind(Peer,peer)).trim()

$static class LivePeer
  name: '$peer'
  list: []
  byHash: {}
  byIRAC: {}
  constructor:->
  collect: (peer)-> Object.keys(@byHash).filter Peer.filter.bind null, peer
  get:(peer,list)-> Peer.filterList peer, list.map( (i) => @byHash[i].item ).trim()
  pull: (source,items...)-> for peer in items
    continue unless p = @list.find (i)-> i.item.irac is peer.irac
    Array.remove @list, p
    delete @byHash[p.hash]
  push: (peer,items...)->
    for p,q in items
      p = new Peer.Shadow p
      hash = Channel.hash r = Peer.filter group:['$peer'], p
      unless item = @byHash[hash]
        @list.push @byHash[hash] = item = hash:hash, item: r, date: p.lastSeen || 0
      else item.date = Date.now()
      items[q] = r
    # console.hardcore '  FIND  '.red.bold.inverse, Peer.format(peer), items
    SyncQueue.distribute peer, '$peer', items, null, Peer.filter

class SyncQueue
  @byIRAC: {}
  @distribute: (source,channel,items,hashed,filter)->
    return unless channel?
    queue = SyncQueue.byIRAC
    connected = Request.connected
    source = $config.hostid         unless source?
    hashed = items.map Channel.hash unless hashed?
    for irac, socket of connected when irac isnt source.irac or irac is $config.hostid.irac
      peer = socket.peer
      direct = peer.direct or channel[0] is '@'
      q = queue[irac] = queue[irac] || {}
      l = if direct then items else hashed
      l = l.map(filter.bind null, peer).filter( (i)-> i? ) if filter
      q[channel] = ( q[channel] = [] ).concat l
    @publish()
  @publish: $async.pushup deadline:100, threshold:100, worker: (cue, done)->
    send = (irac,channels)->
      return unless peer = PEER[irac]
      return unless 0 < Object.keys( channels = Peer.trade_filter channels ).length
      SyncQueue.byIRAC[irac] = {}
      peer.hardcore ' PUBLISHING '.bold.inverse, channels
      Peer.trade peer, null, channels, ->
        peer.hardcore  ' PUBLISHED '.bold.inverse, channels
    send irac, channels for irac, channels of SyncQueue.byIRAC
    done null

###
  CHANNEL-SETUP
###

do Channel.init

###
  PEERING
###

$command peer: Peer.requestAuth = (address)->
  return 'ENOADDRESS' unless address
  Request.static name:address.split('.').shift(),address:address, [
    'irac_peer'
  ], (error,req,body)->
    return console.error error if error
  'calling_' + address

$command irac_peer: $group '$public', (ack)->
  { irac, root, onion, ia } = peer = $$.peer
  accept = (peer,ack)->
    peer = new Peer.Remote remote:peer.cert, cert:ack
    peer.log ' PEERED-WITH '.green.bold.inverse
    setTimeout ( -> Peer.sync peer, (error)-> ), 1000 # TODO: distrust on error
    peer.groups '$peer'
    peer.cert = ack
    do $app.sync
  if ack?
    Object.assign peer, remote:hisCert = $auth.authorize peer
    accept peer, ack
    return hisCert
  Object.assign peer, cert:no, remote: hisCert = $auth.authorize peer
  Request.static peer, [ 'irac_peer', hisCert ], (error,req,myCert)->
    return console.error error if error
    accept peer, myCert
    null
  'calling_back'

###
  SYNC
###

$command sync: (irac)->
  peer = PEER[irac] if irac
  Peer.sync peer
  true

$command irac_sync: $group '$peer', (msg)->
  return false unless peer = $$.peer
  peer.log ' IRAC-SYNC '.yellow.bold.inverse, msg
  Peer.readOpts peer, msg
  o = Channel.offer peer, peer.remoteSync
  o.opts = Peer.opts peer
  o

Peer.sync = (peer,callback)-> want = offer = null; $async.series [
  (c)->
    peer.log ' IRAC-SYNCING-WITH '.blue.bold.inverse, peer.remoteHead
    Request peer, [
      'irac_sync', opts: Peer.opts peer
    ], (error,msg)->
      unless error or msg.error
        peer.hardcore  ' SYNC-REPLY '.white.inverse, msg
        Peer.readOpts peer, msg
        offer = Channel.offer   peer, peer.remoteSync
        want  = Channel.compare peer, msg
        peer.hardcore ' SYNC-WANT '.white.inverse, want if Object.keys(want).length > 0
      else peer.error ' SYNC-ERROR '.red.bold.inverse, error || msg.error
      c error
  (c)-> Peer.trade peer, want, offer, c
  -> do callback if callback ]

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

###
  TRADE
###

Peer.trade = (peer,want,offer,callback)->
  c = 0
  ( want = Peer.trade_filter want; c += Object.keys(want).length )    if want
  ( offer = Peer.trade_filter offer; c += Object.keys(offer).length ) if offer
  if 0 is c
    do callback if callback
    return false
  Request peer, ['irac_trade',want,offer], (error,result)->
    # peer.hardcore  'SYNC-TRADE-RESULT', result
    Channel.push peer, result unless error
    callback error, result if callback
  true

Peer.trade_filter = (map)-> _.omit map, (val,key)-> not ( Array.isArray(val) and val.length > 0 )

Peer.getBlob = (peer,hash)->
  return if $fs.existsSync link = $path.sharedHash hash
  console.log ' IRAC-GET-BLOB '.yellow.inverse.bold, hash
  return if $config.hostid.irac is peer.irac
  Request.pipe peer, ['irac_get',hash], $fs.createWriteStream link

Channel.get = (peer,channels)->
  channels.opts = Peer.opts peer if channels.opts?
  for name,list of channels
    if ( channel = Channel.resolve(name,no) )
      if channel.get
        channels[name] = channel.get peer, list
      else channels[name] = ( item.item || item for hash in list when item = channel.byHash[hash] )
      delete channels[name] if channels[name].length is 0
    else delete channels[name]
  return channels

$command irac_trade: $group '$peer', (want,offer,remoteHead)->
  return false unless peer = $$.peer
  peer.remoteHead = remoteHead if remoteHead?
  if offer? and Object.keys(offer).length > 0
    peer.debug  ' OFFERS '.yellow.bold.inverse, offer
    peer.debug  ' WEWANT '.yellow.bold.inverse, Channel.compare(peer,offer)
    Peer.trade peer, Channel.compare(peer,offer)
  if want? and Object.keys(want).length > 0
    deliver = Channel.get peer, want
    peer.debug  ' WANTS '.yellow.bold.inverse, want
    peer.debug  ' GETS '.yellow.bold.inverse, deliver
    return deliver
  return true

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

$command irac_getall: (channel)->
  Channel.resolve(channel,no).list.map (i)->
    i.item

###
  SUBSCRIPTIONS
###

$command subscribe: (channel)->
  Channel.resolve channel
  do $app.sync
  true

$command unsubscribe: (channel)->
  Channel.remove channel
  do $app.sync
  true

Peer.subscribe = (peer,list=[])->
  uniq = {}; peer.sub = ( peer.sub || [] ).concat( list, [
    '$peer', '$subscribe', '$status', '@' + peer.ra, '@' + peer.irac
  ]).filter (i)->
    return false if (not i?) or i is 'null'
    return false if uniq[i]; uniq[i] = yes

###
  MESSAGES
###

$command say: (to,message...)->
  return unless c = Channel.resolve to
  msg = $auth.signMessage type:'text/utf8', body: message.join ' '
  c.push null, msg
  true

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

$static class IRACStream
  constructor:(to,opts)->
    return unless @dest = Channel.resolve to
    console.log to, @dest
    @msg = $auth.signMessage Object.assign opts,
      date:date=Date.now()
      from:$config.hostid.irac
      body:'= Media Stream ='
      hash:@hash=$sha1($config.hostid.ra + $config.hostid.irac + date)
    IRACStream.byHash[@hash] = @
    @path = $path.sharedHash @hash
    console.log ' STREAM '.white.bold.inverse, @hash, @path
  end:(data)->
    console.log ' STREAM-END '.white.bold.inverse, @hash
    @save.close()
  write:(data)->
    console.log ' STREAM-BEGIN '.white.bold.inverse, @hash
    @save = $fs.createWriteStream @path
    @write = @save.write.bind @save
    @dest.push $config.hostid, @msg
    @write data
  @byHash:{}

$command rec: (to,opts)->
  console.log arguments
  if s = new IRACStream to, opts then s.hash else false

$command chunk:(hash,id,data)-> if data
  console.log ' STREAM-CHUNK '.white.bold.inverse, id, data.length
  return false unless s = IRACStream.byHash[hash]
  return false unless data
  s.write data

$command cut:(hash)->
  return false unless s = IRACStream.byHash[hash]
  s.end()

###
  UTILS
###

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
  item = Object.resolve($config+'.'+id)   unless item
  return false unless item
  for i in ( items = if item.list then item.list else [item] )
    i[key] = value
  do $app.sync
  true

$command ssh_empeer: (host)->
  hostname = $md5 host; peer = null
  $async.series [
    (c)=> $cp.exec """ssh #{host} hostname""", (error,host)=>
      hostname = host.trim() if host and host.trim and host.trim().length > 1
      do c
    (c)=> c null, peer = $auth.createHost hostname, host
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
    (c)=> Peer.sync peer; null ]
