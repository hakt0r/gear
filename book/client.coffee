
if $app? then return $app.on 'web:listening', ->

  $command ui_list:->
    format_peer = (peer)-> Object.assign {},
      date: peer.lastSeen
      root: peer.root
      irac: peer.irac
      name: peer.name
      caname: peer.caname
      online: Request.connected[irac]?
    o = $peer:{}, $channel:{}, $hostid: irac:$config.hostid.irac, root:$config.hostid.root
    for irac, peer of PEER
      o.$peer[irac]      = p = format_peer peer
      o.$peer[peer.root] = r = Object.assign {}, p
      r.irac = r.root
    for name, channel of Channel.byName
      if name[0] is '@'
        o.$peer[name.substr 1].msgout = channel.list.length
      o.$channel[name] = name:name
    return o

  $web.bindLibrary '/cbor.js', 'https://raw.githubusercontent.com/paroga/cbor-js/master/cbor.js'
  $web.bindLibrary '/jquery.js', 'https://ajax.googleapis.com/ajax/libs/jquery/2.2.3/jquery.min.js'
  $web.bindLibrary '/adapter.js', 'http://webrtc.github.io/adapter/adapter-latest.js'
  $web.bindLibrary '/MediaStreamRecorder.js', 'https://cdn.webrtc-experiment.com/MediaStreamRecorder.js'
  $web.bindLibrary '/fontawesome.css', 'https://maxcdn.bootstrapcdn.com/font-awesome/4.6.3/css/font-awesome.min.css'
  $web.bindLibrary '/fonts/fontawesome-webfont.woff2', 'https://maxcdn.bootstrapcdn.com/font-awesome/4.6.3/fonts/fontawesome-webfont.woff2'
  $web.bindLibrary '/fonts/fontawesome-webfont.woff', 'https://maxcdn.bootstrapcdn.com/font-awesome/4.6.3/fonts/fontawesome-webfont.woff'
  $web.bindLibrary '/fonts/fontawesome-webfont.ttf', 'https://maxcdn.bootstrapcdn.com/font-awesome/4.6.3/fonts/fontawesome-webfont.ttf'
  $web.bindLibrary '/events.js', 'https://raw.githubusercontent.com/Olical/EventEmitter/master/EventEmitter.min.js'
  $web.bindCoffee  '/client.js', $path.join 'book', 'client.coffee'
  $web.get '/default.css', (req,res)->
    res.setHeader('Content-Type','text/css')
    $fs.createReadStream($path.join($path.modules,'book/default.css')).pipe res
  $web.get '/', (req,res)->
    res.setHeader('Content-Type','text/html')
    $fs.createReadStream($path.join($path.modules,'book/index.html')).pipe res

do ->
  Array.remove = (a,v) -> a.splice a.indexOf(v), 1

  window.IRAC = new EventEmitter
  ERROR = -1; REQUEST = 0; RESPONSE = 1; s = null

  connect = (connected)->
    return if s
    addr = window.location.toString().replace('http','ws').replace(/#.*/,'').replace(/\/$/,'') + '/rpc'
    s = if WebSocket? then new WebSocket addr else new MozWebSocket addr
    s.binaryType = "arraybuffer"
    s.fail = (error,data)->
      console.error error, data
      # s.send JSON.stringify [ -1, -1, [ error + "\n" + data ] ]
      s.send CBOR.encode([ -1, -1, [ error + "\n" + data ] ]), binary:on, mask:off
    s.onmessage = (m) =>
      # m = JSON.parse m.data
      m = CBOR.decode m.data
      return s.fail 'IRAC-WS-NOT-AN-ARRAY', m unless Array.isArray m
      [ msgType, uid, msg ] = m
      return s.fail 'IRAC-WS-INVALID-STRUCTURE', m unless msgType? and uid? and msg? and msg.push?
      if msgType is REQUEST
        IRAC.emit.apply IRAC, msg.concat (args...)->
          # try s.send JSON.stringify [RESPONSE,uid,args]
          try s.send CBOR.encode([RESPONSE,uid,args])
      else if ( msgType is RESPONSE )
        for request in active.slice() when request.uid is uid
          if typeof ( callback = request[1] ) is 'function'
            callback.apply null, msg
          Array.remove active, request
          break
        null
      else if msgType is ERROR then console.error "IRAC-WS-REMOTE-ERROR", msg.join '\n  '
      else console.error 'IRAC-WS-ILLEGAL', msgType, uid, msg
    s.onopen = (e) -> s.connected = true; do flush
    s.onerror = (e) -> console.error "NET.sock:error", e; s = null
  do connect

  counter = 0; active = []; queue  = []
  flush = ->
    return do connect unless s and s.connected
    for req in queue
      req.uid = counter++
      active.push req
      # s.send JSON.stringify
      s.send CBOR.encode([REQUEST,req.uid,req[0]])
    queue = []

  window.request = (args,callback)->
    queue.push [args,callback]
    do flush
    null

  window.prettyDate = prettyDate = (time) ->
    time = parseInt time
    diff = ((new Date).getTime() - time) / 1000
    day_diff = Math.floor(diff / 86400)
    return htmlentities time if isNaN(day_diff) or day_diff < 0 or day_diff >= 31
    day_diff == 0 and (diff < 60 and 'now' or diff < 120 and '1m' or diff < 3600 and Math.floor(diff / 60) + 'm' or diff < 7200 and '1h' or diff < 86400 and Math.floor(diff / 3600) + 'hrs') or day_diff == 1 and 'yday' or day_diff < 7 and day_diff + 'days' or day_diff < 31 and Math.ceil(day_diff / 7) + 'weeks'

  setInterval ( window.applyDate = -> $('label.date').each (i,e)->
    e.date = $(e).html() unless e.date
    $(e).html prettyDate e.date ), 60000

IRAC.on 'irac_trade', (want,offer,date,callback)->
  Channel.add channel, items for channel, items of offer
  do callback if callback

window.$me = {}

window.Channel = class Channel
  @byName: {}
  @setting: 'all'
  @add:(channel,items)->
    if channel is '$peer'
      o = {}; for k,v of items when v.irac
        o[v.irac] = v; v.irac
      return IRAC.updateList $peer:o
    items = [items] unless Array.isArray items
    items.forEach (i)-> i.channel = channel
    channel = new Channel name:channel, list:items
    do @render
  @render:-> # requestAnimationFrame =>
    $('#feed').html ''
    for item in list = ( @byName[@setting] || list:[] ).list
      t = if item.type then item.type.split('/')[0] else 'default'
      $('#feed').append i = ( Channel[t] || Channel.default )(item,@setting)
    do applyDate
    null
  @set:(@setting,@setname,prompt,@callback)->
    $('#send').html if prompt then prompt else if @setting is 'all' then 'Publish Status' else 'Send to #' + @setting
    @onSend = =>
      unless '' is v = $("#input").val().trim()
        if v[0] is '/'  then request cmd = v.substr(1).split /[ \t]+/
        else if ( c = @callback ) then c v
        else request ['say',( if @setting is 'all' then '$status' else @setting ), v]
      $("#input").val('')
    Channel.render()
    $("#curchannel").html(@setname||@setting)
    $("#actions").html('').append """
      <i message-type="chat"  class="fa fa-envelope"></i>
      <i message-type="achat" class="fa fa-microphone"></i>
      <!--i message-type="vchat" class="fa fa-video-camera"></i-->
      <i message-type="ftp"   class="fa fa-file"></i> """
    $('#actions .fa').each (k,e)->
      e = $ e; e.on 'click', Peer.message[e.attr('message-type')].bind null, @setting, true
    null
  @sortNormal: (a,b)-> parseInt(b.date) - parseInt(a.date)
  constructor:(opts)->
    return ch.update opts if ch = Channel.byName[opts.name]
    Channel.byName[opts.name] = @
    @update opts
    if $me
      Channel.$irac = @ if @name is '@' + $me.irac
      Channel.$root = @ if @name is '@' + $me.root
  update:(opts)->
    Object.assign @, opts
    if @name[0] is '@'
      opts.list = opts.list || []
      opts.list = opts.list.concat ( Channel.$irac || {list:[]} ).list.filter ( (i)-> i.from is @name ) unless @name is '@' + $me.irac
      opts.list = opts.list.concat ( Channel.$root || {list:[]} ).list.filter ( (i)-> i.from is @name ) unless @name is '@' + $me.root
    @list = ( opts.list || [] ).concat ( @list || [] ).sort Channel.sortNormal
    Channel.byName.all.list = Channel.byName.all.list.concat(opts.list || []).sort Channel.sortNormal
    return @ if @name[0] is '$'
    return @ if @name[0] is '@'
    unless ( c = $ '.byChannelName_' + @name ).length > 0
      $('#channel').append c = $ Channel.channel @name
      c.on 'click', Channel.set.bind Channel, @name, @name
    return @

window.Peer = class Peer
  @byCA:{}
  @bySA:{}
  @message:
    chat:(-> do Channel.onSend)
    ftp:->
  constructor: (opts)->
    if sa = Peer.bySA[opts.irac]
      sa.update opts
      return sa
    @update opts
    Peer.bySA[opts.irac] = @
    # console.log @
  update:(opts)->
    Object.assign @, opts
    @name   = @name   || @irac.substr(0,6)
    @caname = @caname || @root.substr(0,6)
    @channelName = '@' + @root
    @peerName = '@' + @irac
    ca = Peer.byCA[opts.root] || Peer.byCA[opts.root] = []
    ca.push @
    ca.name = @caname
    unless ( c = $ '.message.peer.byIrac_' + @root ).length > 0
      $('#peer').prepend c = $ Channel.buddy @root, @caname, @date
      $(c.find('.from')[0]).on 'click', Channel.set.bind Channel, @channelName, @caname
    unless ( e = $ '.message.peer.byIrac_' + @irac ).length > 0
      c.append e = $ Channel.peer @irac, @name
      e.on 'click', Channel.set.bind Channel, @peerName, @name

IRAC.updateList = (items)-> requestAnimationFrame =>
  new Peer    peer    for k,peer    of items.$peer    if items.$peer
  new Channel channel for k,channel of items.$channel when channel.name[0] isnt '@' if items.$channel
  do applyDate

$ ->
  handler = (evt)->
    console.log evt.keyCode
    # if evt.keyCode is 27 then delete Channel.callback; Channel.set Channel.setting
    if evt.keyCode is 13
      do evt.preventDefault
      do Channel.onSend
  $('#input').on 'focus', -> $(window).on 'keydown', handler
  $('#input').on 'blur',  -> $(window).off 'keydown', handler
  $('#send').on 'click', -> do Channel.onSend



Channel.default = (item)-> """
  <div class="message binary">
    <span class="meta">
      <label class="channel">#{htmlentities item.channel}</label>
      <label class="from">#{item.from.substr(0,5)}</label>
      <label class="type">#{htmlentities item.type}</label>
      <label class="date">#{htmlentities item.date}</label>
    </span>
  </div>
"""

htmlentities = (str) ->
  textarea = document.createElement('textarea')
  textarea.innerHTML = str
  textarea.innerHTML

Channel.text = (item)->
  unless name = Peer.byCA[item.from]
    if sa = Peer.bySA[item.from]
      name = sa.name + '.' + Peer.byCA[sa.root].name
    else item.from.substr(0,6)
  else name = name.name
  unless to = Peer.byCA[item.channel]
    if sa = Peer.bySA[item.channel.substr(1)]
      to = sa.name + '.' + Peer.byCA[sa.root].name
    else to = item.channel
  else to = to.name
  """
  <div class="message chat">
    <span class="meta">
      <label class="channel">#{htmlentities to}</label>
      <label class="from">#{htmlentities name}</label>
      <label class="date">#{item.date}</label>
    </span>
    <p class="body chat">#{htmlentities item.body}</p>
  </div>
"""

Channel.image = (item)-> """
  <div class="message chat image">
    <span class="meta">
      <label class="channel">#{htmlentities item.channel}</label>
      <label class="from">#{item.from.substr(0,5)}</label>
      <label class="date">#{htmlentities item.date}</label>
    </span>
    <img src="/rpc/irac_get/#{item.hash}">
    <p class="body chat">#{htmlentities item.body}</p>
  </div>
"""

Channel.video = (item)->
  i = $ """
  <div class="message chat video">
    <span class="meta">
      <label class="channel">#{htmlentities item.channel}</label>
      <label class="from">#{item.from.substr(0,5)}</label>
      <label class="date">#{htmlentities item.date}</label>
    </span>
    <video preload="none" src="/rpc/irac_get/#{item.hash}"></video>
    <p class="body chat">#{htmlentities item.body}</p>
  </div>"""
  i.find('video').hover -> if @hasAttribute "controls" then @removeAttribute "controls" else @setAttribute "controls", "controls"
  return i

Channel.audio = (item)-> """
  <div class="message chat audio">
    <span class="meta">
      <label class="channel">#{htmlentities item.channel}</label>
      <label class="from">#{item.from.substr(0,5)}</label>
      <label class="date">#{htmlentities item.date}</label>
    </span>
    <audio controls preload="none" src="/rpc/irac_get/#{item.hash}"></audio>
    <p class="body chat">#{htmlentities item.body}</p>
  </div>"""

Channel.buddy = (id,name,date)-> """
  <div class="message peer byIrac_#{htmlentities id}">
    <span class="meta">
      <label class="from">#{htmlentities name}</label>
      <label class="date">#{date}</label>
    </span>
    <ul class="peers">
    </ul>
  </div>"""

Channel.peer = (id,name)-> """
  <div class="message peer byIrac_#{htmlentities id}">
    <span class="meta">
      <label class="from">#{htmlentities name}</label>
    </span>
  </div>
"""

Channel.channel = (name)-> """
  <div class="message channel byChannelName_#{htmlentities name}">
    <span class="meta">
      <label class="from">#{htmlentities name}</label>
    </span>
  </div>
"""

request ['ui_list'], (result)->
  window.$me = result.$hostid; delete result.$hostid
  console.log $me
  IRAC.updateList result
  list = ( v.name for k,v of result.$channel )
  console.log 'get', list
  list.map (stream)-> request ['irac_getall',stream], (items)->
    console.log 'got', stream, items
    Channel.add stream, items

$ ->
  new Channel name:'all', list:[]
  Channel.set 'all', 'Status'


Peer.message.achat = (root)-> audio.add root

window.audio = new class AudioChat
  init:(callback)->
    constraints = window.constraints = audio:on, video:off
    navigator.mediaDevices.getUserMedia constraints
     .then (@stream)=> do callback if callback
     .catch (e)-> console.error e
  add: (to)->
    timer = null
    return @remove to if @[to] and @[to].stop
    return @init @add.bind @, to unless @stream
    request ['rec',to,type:'audio/opus'], (hash) =>
      if ( e = $('.peer.byIrac_'+to) ).length isnt 0
        e.find('.actions .fa-microphone').css('backgroundColor','red')
      @[to] = rec = new MediaStreamRecorder @stream
      rec.mimeType = 'audio/opus'
      cid = 0 ; rec.ondataavailable = (blob) ->
        reader = new FileReader
        reader.readAsArrayBuffer blob
        reader.onloadend = ->
          request ['chunk',hash,cid++,new Uint8Array reader.result]
          clearTimeout timer
          timer = setTimeout ( -> request ['cut',hash] ), 2000
        null
      rec.start 500
    @[to] = 1
  remove: (to)->
    if ( e = $('.peer.byIrac_'+to) ).length isnt 0
      e.find('.actions .fa-microphone').css('backgroundColor','#FFE69D')
    try @[to].stop()
    delete @[to]

###
Peer.message.vchat = (root)-> new VChat "@" + root
Peer.message.vchat_stop = (root)-> vchat.stop() if vchat


class VChat
  constructor:(@to)->
    window.vchat = @
  stop:(hash)->
    @recorder.stop()
    @frame.remove()
    @stopped = true
  init:(hash)->
    unless video = $('video.chat')[0]
      $('body').append @frame = $ """
        <div class="message videochat">
          <span class="meta"><label class="from">#{@to}</label></span>
          <span class="actions">
            <i message-type="vchat_stop" class="fa fa-close"></i>
          </span>
          <video muted class="chat out" />
          <video muted class="chat in" />
        </div>"""
      @frame.find('.actions .fa').each (k,e)-> $(e).on 'click', Peer.message[$(e).attr('message-type')]
      video = $('video.chat')[0]
    errorElement = document.querySelector('#errorMsg')
    constraints = window.constraints = audio:on, video:on
    errorMsg = (msg, error) ->
      console.error msg, error
      return
    navigator.mediaDevices.getUserMedia(constraints)
      .then (stream) =>
        options = mimeType: 'video/webm', audioBitsPerSecond: 128000, videoBitsPerSecond: 128000, bitsPerSecond: 128000, quality: 0.2
        @recorder = new MediaStreamRecorder(stream)
        @recorder.mimeType = 'video/webm'
        cid = 0; # hdr =no
        @recorder.onstop = ->
          request ['cut',@hash]
        @recorder.ondataavailable = (blob) ->
          reader = new FileReader
          reader.readAsArrayBuffer blob
          reader.onloadend = ->
            # return if reader.result.byteLength < 500 and hdr
            request ['chunk',hash,cid++,new Uint8Array reader.result]
            hdr = yes
          return
        @recorder.start 3000
        video.srcObject = stream
        video.play()
        null
      .catch (error) ->
        if error.name == 'ConstraintNotSatisfiedError'
          errorMsg 'The resolution ' + constraints.video.width.exact + 'x' + constraints.video.width.exact + ' px is not supported by your device.'
        else if error.name == 'PermissionDeniedError'
          errorMsg 'Permissions have not been granted to use your camera and ' + 'microphone, you need to allow the page access to your devices in ' + 'order for the demo to work.'
        errorMsg 'getUserMedia error: ' + error.name, error
        null
    null
###
