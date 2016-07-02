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

return unless $require -> @npm 'mime'; @mod 'rpc', 'auth'

$app.resolvePlugin.unshift (id)-> return Peer.byCA[id.substr(1)] || PEER[id.substr(1)] || false if id[0] is '@'; null
$app.resolvePlugin.unshift (id)-> return Message.resolveTag(tag.substr(1),no)          || false if id[0] is '#'; null

$app.on 'daemon', -> $app.messageStore = new Storage
  name: 'message'
  revive: (data)-> new Message data
  preWrite:-> Message.byDate.slice()
  filter:(i)-> date:i.date, hash:i.hash, raw:i.raw
  firstRead:-> $app.on 'sync', (q,defer)-> $app.messageStore.write defer 'messages'

fail = (msg,opts)-> console.error msg.error, opts

$static class Message
  @byTag:  {}
  @byHash: {}
  @byDate: []
  constructor:(opts)->
    Object.assign @, opts
    @hash = Message.hash @raw
    return msg if msg = Message.byHash[@hash] || Message.pending[@hash]
    unless @raw.type and @raw.tag and @raw.irac and @raw.sign and Array.isArray @raw.tag
      fail ' INCOMPLETE-MESSAGE ', opts
      return false
    unless true is @verified = $auth.verifyMessage @raw
      if false is @verified then fail ' INVALID-MESSAGE ', opts.hash
      else Message.pendingVerification @peer, @hash, @raw
      return false
    @date = Date.now() unless @date
    Message.byHash[@hash] = @
    Array.blindSortedPush Message, 'byDate', @
    Array.blindSortedPush Message.byTag, t, @ for t in [@raw.type].concat @raw.tag
    MessageSync.distribute @peer, [@]
    Message.getBlob @raw.hash, @peer if @raw.hash
    # console.debug Peer.format(@peer), ' MESSAGE '.green.inverse, @raw
  destructor:->
    Array.destructiveRemove Message, 'byDate', @
    Array.destructiveRemove Message.byTag[t] for t in [@type].concat @raw.tag
    delete Message.byHash[@hash]
  encodeCBOR:-> date:@date, hash:@hash, raw:@raw

###
  MESSAGE-TYPES
###

Message.getTags = (str)-> str.match(/^[#@$][a-zA-Z0-9_]+/g).unique.trim
Message.stripTags = (body,tags=[])->
  while tag = body.trim().match /^[#@$][a-zA-Z0-9_]+/
    tags.push tag[0]
    body = body.substr tag[0].length
  return [body,tags]
  str.match(/^[#@$][a-zA-Z0-9_]+/g).unique.trim

Message.peer = (peer)-> new Message peer: peer, ttl:60000, raw: $auth.signMessage
  tag: ['$peer'], type: 'x-irac/peer', seen: irac: peer.irac, ia: peer.ia, ra: peer.ra, onion: peer.onion

Message.peerLost = (peer)-> new Message peer: peer, ttl:60000, raw: $auth.signMessage
  tag: ['$peer'], type: 'x-irac/peer', lost: irac: peer.irac, ia: peer.ia, ra: peer.ra, onion: peer.onion

Message.chat = (body)->
  [ body, tags ] = Message.stripTags body
  tags = ['$status'] if tags.length is 0
  new Message raw: $auth.signMessage tag:tags, type:'text/utf8', irac:$auth.irac, body:body

Message.file = (path,tag...)->
  tag = ['file'].concat tag
  hash = null; i = $cp.spawn 'sha1sum', [file]
  # console.debug ' HASHING ', file
  i.stdout.on 'data', (d)-> hash = d.toString().replace(/\ .*/, '').trim()
  i.on 'close', (status,signal)->
    # console.debug status, hash
    return unless status is 0
    mime = require 'mime'
    # console.debug 'share', file, hash
    link = $path.sharedHash hash
    $fs.symlinkSync file, link unless $fs.existsSync link
    new Message raw: $auth.signMessage
      type: mime.lookup file
      body: "File: " + $path.basename file
      size: $fs.statSync(file).size
      hash: hash
      tag: tag
    null
  null

###
  MESSAGE-UTILS
###

Message.dateSearch = (o,a,date)->
  return [] unless ( list = o[a] ) and list.length > 0
  return [] if list[0].date <= date
  return list if list.last.date > date
  return list.slice(0,idx) for i,idx in list when i.date > date
  return []

Message.hash = (item)->
  $md5 JSON.stringify item

Message.resolveTag = (tag,create=on)->
  return list if list = Message.byTag[tag]
  return Message.byTag[tag] = [] if create
  false

Message.getBlob = (hash,peer)->
  return if $fs.existsSync link = $path.sharedHash hash
  console.debug ' IRAC-GET-BLOB '.warn, hash
  return if $auth.irac is peer.irac
  Request.pipe peer, ['irac_get',hash], $fs.createWriteStream link if peer
  # TODO: $dht.search hash, (peer)-> ...

###
  UNVERIFIED MESSAGES
###

Message.pending = {}
Message.pendingVerification = (peer,hash,msg)->
  Message.pending[hash] = msg
  Peer.resolve peer

###
  SYNC
###

$static class MessageSync
  @byIRAC: {}
  constructor:(@peer)->
    return instance if instance = MessageSync.byIRAC[@peer.irac]
    @peer.HEAD = 0 unless typeof @peer.HEAD is 'number'
    MessageSync.byIRAC[@peer.irac] = $evented @
    @offered = []
    # @peer.log ' NEW-SYNC '.error, @peer.HEAD

  request:(opts)->
    opts = have: do @offer unless opts
    if ( not opts.force ) and 0 is Object.keyCount opts = Object.trim opts
      @peer.log ' NO-SYNC '.warn, @peer.HEAD, opts
      @emit 'sync'
    else
      # @peer.log ' SYNC '.warn, @peer.HEAD, opts, @offered
      Request @peer, ['irac_sync',opts], (error,result)=>
        # @peer.log ' SYNC-RESULT '.warn, result
        return if 0 is Object.keyCount remainder = @query result
        # @peer.log ' SYNC-REMAINDER '.warn, remainder
        setImmediate => @request remainder
        null
    return @

  query:(opts)->
    @peer.HEAD = @offered.map( (i)-> Message.byHash[i].date ).concat( @peer.HEAD || 0 ).sort().reverse()[0]
    @offered = if @offered.length isnt 0 then [@offered[0]] else []
    @peer.log ' SYNC-QUERY '.warn, @peer.HEAD, opts
    result = {}
    @recieve opts.push               if opts.push
    result.want = @compare opts.have if opts.have
    result.push = @get     opts.want if opts.want
    result.have = do @offer
    result = Object.trim result
    @peer.log ' SYNC-REPLY '.ok, result
    @emit 'sync', result
    result

  recieve: (list)-> new Message raw:msg, peer:@peer for msg in list when not Message.byHash[Message.hash msg]
  compare: (list)-> list.filter (i)-> not Message.byHash[i]?

  offer: ->
    have = Message.dateSearch Message, 'byDate', @peer.HEAD || 0
    have = have.filter MessageFilter @peer, Peer.subscribe @peer
    have = have.map (i) -> i.hash
    @offered = @offered.concat have
    return have

  get: (list)->
    list.map( (i)-> Message.byHash[i] ).trim.filter( MessageFilter @peer, Peer.subscribe @peer ).map (i)-> i.raw

  @queue: {}
  @distribute: (source,items)->
    # console.debug ' MESSAGE-DISTRIBUTE '.bolder, items.length
    queue = MessageSync.queue
    connected = Request.connected
    source = $auth unless source?
    for irac, socket of connected when irac isnt source.irac or irac is $auth.irac
      Array.blindConcat MessageSync.queue, irac, items.filter (i)-> MessageFilter socket.peer
    do @trigger
  @trigger: $async.pushup deadline:100, threshold:100, worker: (cue, done)->
    $app.sync()
    # console.debug ' MESSAGE-QUEUE '.bolder
    send = (irac,list)->
      # console.debug ' SEND '.bolder, irac, list.length
      return unless peer = PEER[irac]
      return unless 0 < list.length
      # peer.hardcore ' PUBLISHING '.bolder, list.length
      ( new MessageSync peer ).request( push:list.map (i)-> i.raw ).once 'sync', ->
        # peer.hardcore  ' PUBLISHED '.bolder, list.length
      MessageSync.queue[irac] = []
    send irac, list for irac, list of MessageSync.queue
    done null

Peer.sync = (peer,callback=$nullfn)->
  ( new MessageSync peer ).request( force:on ).once 'sync', callback

Peer.subscribe = (peer,list=[],uniq={})->
  return peer.sub = ( peer.sub || [] ).concat( list, [
    '$peer', '$subscribe', '$status', '@' + peer.ra, '@' + peer.irac
  ]).filter (i)->
    return false if (not i?) or i is 'null'
    return false if uniq[i]; uniq[i] = yes

$static MessageFilter: ( peer, sub = Peer.subscribe(peer) ) -> ( item )->
  return false unless Array.oneSharedItem sub, item.raw.tag
  return true  unless filters = MessageFilter.byType[item.raw.type]
  return false for f in filters when not f peer, item
  return true

MessageFilter.byType = {}
MessageFilter.add = (type,callback)->
  Array.blindPush MessageFilter.byType, type, callback

MessageFilter.add 'x-irac/peer', (peer,i)->
  return false unless peer? and i? and ACL.check peer, '$local', '$host', '$peer'
  return false if ( i.irac is peer.irac ) or ( i.irac is $auth.irac )
  return true

###
  API-COMMANDS
###

$command irac_peer: $group '$public', (ack)->
  { irac, root, onion, ia } = peer = $$.peer
  accept = (peer,ack)->
    do $app.sync
    peer.groups '$peer'
    peer.cert = ack
    peer.log ' PEERED-WITH '.ok
    setTimeout ( -> Peer.sync peer, (error)-> ), 1000 # TODO: distrust on error
  unless ack?
    Object.assign peer, cert:no, remote: hisCert = $auth.authorize peer
    Request.static peer, [ 'irac_peer', hisCert ], (error,req,myCert)->
      return console.error error if error
      accept peer, myCert
      null
    'calling_back'
  else
    Object.assign peer, remote:hisCert = $auth.authorize peer
    accept peer, ack
    return hisCert

$command irac_sync: $group '$peer', (opts)->
  ( new MessageSync $$.peer, inbound:true ).query opts

$command irac_get: $group '$peer', (msg)->
  try
    file = $fs.realpathSync link = $path.sharedHash msg
    meta = $config.meta[msg] || require('mime').lookup file
  catch e then file = null
  if $$.web
    { req, res, next } = $$.web; $$.pipe = on
    if file and $fs.existsSync link
      req.url = '/' + msg
      console.debug ' REQ '.whiteBG.black.bold, req.url, meta
      $web.static req, res, next
    else
      res.status 504
      res.end 'Resource temporarily unavailable'
  else if $fs.existsSync link
    $fs.readFileSync link
  else false

###
  COMMANDS
###

$command peer: Peer.requestAuth = (address)->
  return 'ENOADDRESS' unless address
  Request.static name:address.split('.').shift(),address:address, [
    'irac_peer'
  ], (error,req,body)->
    return console.error error if error
  'calling_' + address

$command sync: (irac)-> Peer.sync PEER[irac]; true

$command subscribe:   (tag)-> $config.subscribe.pushUnique tag; do $app.sync; true
$command unsubscribe: (tag)-> $config.subscribe.remove tag;   do $app.sync; true

$command say: (message...)-> Message.chat message.join ' '

$command share: (channel,file)->
  return false unless $fs.existsSync file
  Message.file file

$command rec: (body,opts)->
  [ opts.body, opts.tag ] = Message.stripTags body
  if s = new IRACStream opts then s.hash else false

$command chunk:(hash,id,data)-> if data
  console.debug ' STREAM-CHUNK '.bolder, id, data.length
  return false unless s = IRACStream.byHash[hash]
  return false unless data
  s.write data

$command cut:(hash)->
  return false unless s = IRACStream.byHash[hash]
  s.end()

$static class IRACStream
  constructor:(opts={})->
    return false unless opts.tag
    @msg = new Message peer:$auth, raw: $auth.signMessage Object.assign opts,
      tag:opts.tag
      date:date=Date.now()
      irac:$auth.irac
      body:opts.body||'= Media Stream ='
      hash:@hash = $sha1 $auth.ra + $auth.irac + date + opts.tag.join ''
    IRACStream.byHash[@hash] = @
    @path = $path.sharedHash @hash
    $config.meta[@hash] = @msg.raw
    console.debug ' STREAM '.bolder, @hash, @path
  end:(data)->
    console.debug ' STREAM-END '.bolder, @hash
    @save.close()
  write:(data)->
    console.debug ' STREAM-BEGIN '.bolder, @hash
    @save = $fs.createWriteStream @path
    @write = @save.write.bind @save
    @write data
  @byHash:{}

$command tags: -> Object.keys Message.byTag

$command show: (tag)->
  Message.resolveTag(tag,no).list.map (i)->
    i = i.item
    i.irac.substr(0,5) + ": " + i.body

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
