
if $app? then return $app.on 'web:listening', ->
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

prettyDate = (time) ->
  time = parseInt time
  diff = ((new Date).getTime() - time) / 1000
  day_diff = Math.floor(diff / 86400)
  return htmlentities time if isNaN(day_diff) or day_diff < 0 or day_diff >= 31
  day_diff == 0 and (diff < 60 and 'now' or diff < 120 and '1m' or diff < 3600 and Math.floor(diff / 60) + 'm' or diff < 7200 and '1h' or diff < 86400 and Math.floor(diff / 3600) + 'hrs') or day_diff == 1 and 'yday' or day_diff < 7 and day_diff + 'days' or day_diff < 31 and Math.ceil(day_diff / 7) + 'weeks'

setInterval ( applyDate = -> $('label.date').each (i,e)->
  e.date = $(e).html() unless e.date
  $(e).html prettyDate e.date ), 60000

IRAC.on 'irac_trade', (want,offer,date,callback)->
  Channel.add channel, items for channel, items of offer
  do callback if callback

window.Channel = class Channel
  @byName: all: []
  @setting: 'all'
  @add:(channel,items)->
    return Channel.addPeers items if channel is 'peer'
    items = [items] unless Array.isArray items
    items.forEach (i)-> i.channel = channel
    @byName.all = @byName.all.concat(items).sort (a,b)-> parseInt(b.date) - parseInt(a.date)
    @byName[channel] = ( @byName[channel] || [] ).concat(items).sort (a,b)-> parseInt(b.date) - parseInt(a.date)
    requestAnimationFrame => do @render
  @render:-> requestAnimationFrame =>
    $('#feed').html ''
    for item in list = @byName[@setting] || @byName[@setting] = []
      t = if item.type then item.type.split('/')[0] else 'default'
      $('#feed').append i = ( Channel[t] || Channel.default )(item,@setting)
    do applyDate
    null
  @set:(@setting,prompt,@callback)->
    $('#send').html if prompt then prompt else if @setting is 'all' then 'Publish Status' else 'Send to #' + @setting
    @onSend = =>
      unless '' is v = $("#input").val().trim()
        if v[0] is '/'  then request cmd = v.substr(1).split /[ \t]+/
        else if ( c = @callback ) then c v
        else request ['say',( if @setting is 'all' then 'status' else @setting ), v]
      $("#input").val('')
    Channel.render()
    null
  @addPeers: (items)-> requestAnimationFrame =>
    items.map (i)=>
      return unless i? and i.root? and i.from?
      unless ( c = $ '.message.peer.byIrac' + i.root ).length > 0
        $('#peer').prepend c = $ @buddy i, i.root
        c.find('.actions .fa').each (k,e)->
          e = $ e
          e.on 'click', Peer.message[e.attr('message-type')].bind null, i.root
      unless ( e = $ '.message.peer.byIrac' + i.from ).length > 0
        c.append e = $ @peer i, i.from
      #$('.peer').each(k,e) remove()
    do applyDate

Peer = message:
  chat:(root)-> Channel.set "@" + root, "@" + root.substr(0,6), (message)-> request ['say',"@" + root,message]
  ftp:->

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

Channel.text = (item)-> """
  <div class="message chat">
    <span class="meta">
      <label class="channel">#{htmlentities item.channel}</label>
      <label class="from">#{htmlentities item.from.substr(0,5)}</label>
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

Channel.buddy = (item,id)-> """
  <div class="message peer byIrac#{htmlentities id}">
    <span class="actions">
      <i message-type="chat"  class="fa fa-envelope"></i>
      <i message-type="achat" class="fa fa-microphone"></i>
      <!--i message-type="vchat" class="fa fa-video-camera"></i-->
      <i message-type="ftp"   class="fa fa-file"></i>
    </span>
    <span class="meta">
      <label class="from">#{htmlentities item.caname||id.substr(0,5)}</label>
      <label class="date">#{item.date}</label>
    </span>
    <ul class="peers">
    </ul>
  </div>
"""

Channel.peer = (item,id)-> """
  <div class="message peer byIrac#{htmlentities id}">
    <span class="meta">
      <label class="from">#{htmlentities item.name||id.substr(0,5)}</label>
    </span>
  </div>
"""

request ['list'], (list)->
  $('#feeds').html ''
  ['all'].concat(list).map (stream)->
    return if stream[0] is '@'
    return unless -1 is ['peer'].indexOf stream
    hstream = htmlentities stream
    $('#feeds').append btn = $ """<button id="show_#{hstream}">#{hstream}</button>"""
    btn.on 'click', Channel.set.bind Channel, stream, ( if stream[0] is '@' then 'Send to ' + stream.substr(0,7) ), null
    null
  list.map (stream)-> request ['irac_getall',stream], (items)-> Channel.add stream, items

$ -> Channel.set 'all'


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
      if ( e = $('.peer.byIrac'+to) ).length isnt 0
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
    if ( e = $('.peer.byIrac'+to) ).length isnt 0
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
