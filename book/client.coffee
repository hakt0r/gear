
if $app? then return $app.on 'web:listening', ->
  $web.bindLibrary '/jquery.js', 'https://ajax.googleapis.com/ajax/libs/jquery/2.2.3/jquery.min.js'
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

connect = ->
  return if s
  addr = window.location.toString().replace('http','ws').replace(/#.*/,'').replace(/\/$/,'') + '/rpc'
  s = if WebSocket? then new WebSocket addr else new MozWebSocket addr
  s.fail = (error,data)->
    console.error error, data
    s.send JSON.stringify [ -1, -1, [ error + "\n" + data ] ]
  s.onmessage = (m) =>
    m = JSON.parse m.data
    return s.fail 'IRAC-WS-NOT-AN-ARRAY', m unless Array.isArray m
    [ msgType, uid, msg ] = m
    return s.fail 'IRAC-WS-INVALID-STRUCTURE', m unless msgType? and uid? and msg? and msg.push?
    if msgType is REQUEST
      IRAC.emit.apply IRAC, msg.concat (args...)-> try s.send JSON.stringify [RESPONSE,uid,args]
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
    s.send JSON.stringify [REQUEST,req.uid,req[0]]
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
  day_diff == 0 and (diff < 60 and 'just now' or diff < 120 and '1 minute ago' or diff < 3600 and Math.floor(diff / 60) + ' minutes ago' or diff < 7200 and '1 hour ago' or diff < 86400 and Math.floor(diff / 3600) + ' hours ago') or day_diff == 1 and 'Yesterday' or day_diff < 7 and day_diff + ' days ago' or day_diff < 31 and Math.ceil(day_diff / 7) + ' weeks ago'

setInterval ( applyDate = -> $('label.date').each (i,e)->
  e.date = $(e).html() unless e.date
  $(e).html prettyDate e.date ), 60000

IRAC.on 'irac_trade', (want,offer,date,callback)->
  Channel.add channel, items for channel, items of offer
  do callback

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
  @set:(@setting)->
    $('#send').html if @setting is 'all' then 'Publish Status' else 'Send to #' + @setting
    $('#send').on 'click', @onSend = =>
      unless '' is v = $("#input").val().trim()
        if v[0] is '/'
          request cmd = v.substr(1).split /[ \t]+/
        else request ['say',( if @setting is 'all' then 'status' else @setting ), v]
      $("#input").val('')
    Channel.render()
    null
  @addPeers: (items)-> requestAnimationFrame => items.map (i)=>
    console.log i
    $('#peer .byIrac'+i.from).remove()
    $('#peer').prepend e = $ @peer i
    do applyDate

$(window).on 'keydown', (evt)->
  if evt.keyCode is 13
    do evt.preventDefault
    do Channel.onSend

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

Channel.peer = (item)-> """
  <div class="message peer byIrac#{htmlentities item.from}">
    <span class="meta">
      <label class="from">#{htmlentities item.from.substr(0,5)}</label>
      <label class="date">#{item.date}</label>
    </span>
  </div>
"""

request ['list'], (list)->
  $('#feeds').html ''
  ['all'].concat(list).map (stream)->
    return unless -1 is ['peer'].indexOf stream
    hstream = htmlentities stream
    $('#feeds').append btn = $ """<button id="show_#{hstream}">#{hstream}</button>"""
    btn.on 'click', Channel.set.bind Channel, stream
    null
  list.map (stream)-> request ['irac_getall',stream], (items)-> Channel.add stream, items

$ -> Channel.set 'all'
