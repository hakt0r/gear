
if $app? then return $app.on 'web:listening', ->

  $command ui_getall: -> ( v.raw for k,v of Message.byHash )
  $command ui_list:->
    format_peer = (peer)-> Object.assign {},
      date: peer.lastSeen
      ia: peer.ia
      ra: peer.ra
      irac: peer.irac
      onion: peer.onion
      name: peer.name
      caname: peer.caname
      online: Request.connected[irac]?
    o = $peer:{}, $all:{}, $hostid: format_peer $auth
    for irac, peer of PEER
      o.$peer[irac]      = p = format_peer peer
      o.$peer[peer.ra] = r = Object.assign {}, p
      r.irac = r.ra
    o.$all = Message.byDate.map (i)-> i.raw
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

IRAC.on 'irac_sync', (opts,callback)->
  Message.add item for item in opts.push if opts.push
  callback {} if callback

window.$me = {}

IRAC.updateList = (items)-> requestAnimationFrame =>
  new Peer    peer for k,peer of items.$peer if items.$peer
  new Message msg  for msg    in items.$all  if items.$all
  do applyDate

$ -> request ['ui_list'], (result)->
  window.$me = new Peer result.$hostid; delete result.$hostid
  IRAC.updateList result
  list = ( v.name for k,v of result.$tag )
  console.log 'get', list
  request ['ui_getall'], (items)-> Message.add item for item in items

  handler = (evt)->
    console.log evt.keyCode
    # if evt.keyCode is 27 then delete Message.callback; View.set View.setting
    if evt.keyCode is 13
      do evt.preventDefault
      do View.onSend
  $('#input').on 'focus', -> $(window).on 'keydown', handler
  $('#input').on 'blur',  -> $(window).off 'keydown', handler
  $('#send').on 'click', -> do View.onSend
  new Message tag:['$all'], type:'text/utf8', body:'loaded', irac:$me.irac, date: Date.now()
  View.set '$all', 'Status'













window.Message = class Message
  @byCA: {}
  @byIRAC: {}
  @byTag: {}
  constructor:(opts)->
    Object.assign @, opts
    Message.byCA[Peer.bySA[opts.irac].ra] = @
    Message.byIRAC[opts.irac] = @
    Message.implicitSortedPush Message.byTag, t, @ for t in @tag.concat ['$all']
    View.update opts

Message.add = (item)->
  return new Peer item if item.type is 'x-irac/peer'
  new Message item
  do View.render

Message.implicitSortedPush = (o,a,e)->
  return o[a] = [e] unless ( list = o[a] ) and list.length > 0
  return            unless -1 is list.indexOf e
  return list.unshift e if list[0].date > e.date
  break for item, idx in list when item.date > e.date
  list.splice idx, 0, e

Message.default = (item)-> """
  <div class="message binary">
    <span class="meta">
      <label class="tags">#{htmlentities item.tag.join ', '}</label>
      <label class="from">#{item.irac.substr(0,5)}</label>
      <label class="type">#{htmlentities item.type}</label>
      <label class="date">#{htmlentities item.date}</label>
    </span>
  </div>
"""

htmlentities = (str) ->
  textarea = document.createElement('textarea')
  textarea.innerHTML = str
  textarea.innerHTML

String::color = (color) -> '<span style="color:'+color+'">' + @ + '</span>'
addcolor = (color)-> Object.defineProperty String::, color, get: -> @color color
addcolor c for c in ['red','white','green','black','yellow','blue']
Object.defineProperty String::, 'bold', get: -> '<b>' + @ + '</b>'

Message.text = (item)->
  if peer = Peer.byCA[item.irac]
    name = Peer.format peer
  else if peer = Peer.bySA[item.irac]
    name = Peer.format peer
  else name = htmlentities item.irac
  to = item.tag.map (i)-> switch i[0]
    when '@' then ( if sa = Peer.bySA[i.substr 1] then Peer.format sa else item.irac.substr(0,6) )
    when '#' then htmlentities i
    when '$' then htmlentities i
    else 'ILLEGAL-TAG ' + htmlentities i
  """
  <div class="message chat">
    <span class="meta">
      <label class="channel">#{to.join ', '}</label>
      <label class="from">#{name}</label>
      <label class="date">#{item.date}</label>
    </span>
    <p class="body chat">#{htmlentities item.body}</p>
  </div>
  """

Message.image = (item)-> """
  <div class="message chat image">
    <span class="meta">
      <label class="channel">#{htmlentities item.tag.join ', '}</label>
      <label class="from">#{item.irac.substr(0,5)}</label>
      <label class="date">#{htmlentities item.date}</label>
    </span>
    <img src="/rpc/irac_get/#{item.hash}">
    <p class="body chat">#{htmlentities item.body}</p>
  </div>
"""

Message.video = (item)->
  i = $ """
  <div class="message chat video">
    <span class="meta">
      <label class="channel">#{htmlentities item.tag.join ', '}</label>
      <label class="from">#{item.irac.substr(0,5)}</label>
      <label class="date">#{htmlentities item.date}</label>
    </span>
    <video preload="none" src="/rpc/irac_get/#{item.hash}"></video>
    <p class="body chat">#{htmlentities item.body}</p>
  </div>"""
  i.find('video').hover -> if @hasAttribute "controls" then @removeAttribute "controls" else @setAttribute "controls", "controls"
  return i

Message.audio = (item)-> """
  <div class="message chat audio">
    <span class="meta">
      <label class="channel">#{htmlentities item.tag.join ', '}</label>
      <label class="from">#{item.irac.substr(0,5)}</label>
      <label class="date">#{htmlentities item.date}</label>
    </span>
    <audio controls preload="none" src="/rpc/irac_get/#{item.hash}"></audio>
    <p class="body chat">#{htmlentities item.body}</p>
  </div>"""

Message.buddy = (id,name,date)-> """
  <div class="message peer byIrac_#{htmlentities id}">
    <span class="meta">
      <label class="from">#{htmlentities name}</label>
      <label class="date">#{date}</label>
    </span>
    <ul class="peers">
    </ul>
  </div>"""

Message.peer = (id,name)-> """
  <div class="message peer byIrac_#{htmlentities id}">
    <span class="meta">
      <label class="from">#{htmlentities name}</label>
    </span>
  </div>
"""

Message.channel = (name)-> """
  <div class="message channel byMessageName_#{htmlentities name}">
    <span class="meta">
      <label class="from">#{htmlentities name}</label>
    </span>
  </div>
"""










window.Peer = class Peer
  @byCA:{}
  @bySA:{}
  @message:
    chat:(-> do View.onSend )
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
    return console.log 'NO-IRAC', @, opts unless @irac
    @name   = @name   || @irac.substr(0,6)
    @caname = @caname || @ra.substr(0,6) if @caname or @ra
    @channelName = '@' + @ra
    @peerName = '@' + @irac
    ca = Peer.byCA[opts.ra] || Peer.byCA[opts.ra] = []
    ca.push @
    ca.name = @caname
    unless ( c = $ '.message.peer.byIrac_' + @ra ).length > 0
      $('#peer').prepend c = $ Message.buddy @ra, @caname, @date
      $(c.find('.from')[0]).on 'click', => View.set @channelName, @caname
    unless ( e = $ '.message.peer.byIrac_' + @irac ).length > 0
      c.append e = $ Message.peer @irac, @name
      e.on 'click', => View.set @peerName, @name

Peer.format = (peer)->
  return ' NULL '.red.bold.inverse unless peer
  o = []
  o.push ( peer.onion || 'XX' ).substr(0,2).white.bold
  o.push ( peer.irac  || 'XX' ).substr(0,2).yellow.bold
  o.push ( peer.ia    || 'XX' ).substr(0,2).blue.bold
  o.push ( peer.ra    || 'XX' ).substr(0,2).green.bold
  o = o.concat ['[',peer.name.substr(0,6).green.bold,']'] if peer.name
  o = o.join ''
  if peer.group
    o += '[' + ACL.highest(peer.group).white.bold + ']'
  if peer.address
    o + '[' + ( if peer.address is peer.irac then DIRECT[peer.address] || "n/a" else peer.address ).yellow.bold + ']'
  else o










class IRACView
  constructor:->
    @setting = '$all'
  update:->
    do View.render
    return
    Object.assign @, opts
    if @name[0] is '@'
      opts.list = opts.list || []
      opts.list = opts.list.concat ( Message.$irac || {list:[]} ).list.filter ( (i)-> i.irac is @name ) unless @name is '@' + $me.irac
      opts.list = opts.list.concat ( Message.$root || {list:[]} ).list.filter ( (i)-> i.irac is @name ) unless @name is '@' + $me.ra
    @list = ( opts.list || [] ).concat ( @list || [] ).sort Message.sortNormal
    Message.byName.all.list = Message.byName.all.list.concat(opts.list || []).sort Message.sortNormal
    return @ if @name[0] is '$'
    return @ if @name[0] is '@'
    unless ( c = $ '.byMessageName_' + @name ).length > 0
      $('#channel').append c = $ Message.channel @name
      c.on 'click', View.set.bind Message, @name, @name
    return @

  render:-> # requestAnimationFrame =>
    $('#feed').html ''
    for item in list = Message.byTag[@setting] || []
      t = if item.type then item.type.split('/')[0] else 'default'
      $('#feed').prepend i = ( Message[t] || Message.default )(item,@setting)
    do applyDate
    null

  set:(setting,@setname,prompt,@callback)->
    @setting = setting
    $('#send').html if prompt then prompt else if @setting is 'all' then 'Publish Status' else 'Send to #' + @setting
    @onSend = =>
      unless '' is v = $("#input").val().trim()
        if v[0] is '/'  then request cmd = v.substr(1).split /[ \t]+/
        else if ( c = @callback ) then c v
        else request ['say',( if @setting is '$all' then '$status' else @setting ), v]
      $("#input").val('')
    View.render()
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

Object.defineProperty IRACView::, 'setting',
  get: -> @_setting
  set: (filter)->
    # debugger
    return unless filter isnt @setting
    @_setting = filter

window.View = new IRACView









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
