
if $app? then return unless $require( -> @mod 'rpc' ); return $app.on 'web:listening', ->
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

  $web.bindLibrary '/montserrat.css', 'https://fonts.googleapis.com/css?family=Montserrat:400,700&type=woff2', 'text/css',
    (err,req,body)->
      urls = ( body = body.replace(/ttf/g,'woff2') ).match /http.*woff2/g
      console.log urls
      $web.bindLibrary u1='/montserrat.woff2', urls[0]
      $web.bindLibrary u2='/montserrat.woff2', urls[1]
      body.replace(urls[0],u1).replace(urls[1],u2)











Array::trim =   -> return ( @filter (i)-> i? and i isnt false ) || []
Array::unique = -> u={}; @filter (i)-> return u[i] = on unless u[i]; no

window.fnv = (s) ->
  h = 0; i = 0; s = s.toString()
  while i < s.length
    h ^= s.charCodeAt i
    h += (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24);
    i++
  return ( h >>> 0 ).toString 36








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
  window.$me = result.$hostid; window.$me = new Peer result.$hostid; delete result.$hostid
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
  @byUID: {}
  constructor:(opts)->
    Object.assign @, opts
    return m if m = Message.byUID[@sign]
    @tag = @tag.filter (i)-> -1 is ['$peer'].indexOf i
    Message.byUID[@sign] = @
    Message.byCA[Peer.bySA[@irac].ra] = @
    Message.implicitSortedPush Message.byIRAC, @irac, @ for t in @tag.concat ['$all']
    Message.implicitSortedPush Message.byTag, t, @ for t in @tag.concat ['$all']
    View.update @

Message.add = (item)->
  requestAnimationFrame -> do View.render
  return Peer.handle item if item.type is 'x-irac/peer'
  new Message item

Message.implicitSortedPush = (o,a,e)->
  return o[a] = [e] unless ( list = o[a] ) and list.length > 0
  return            unless -1 is list.indexOf e
  return list.unshift e if list[0].date > e.date
  break for item, idx in list when item.date > e.date
  list.splice idx, 0, e

Message.default = (item)-> """
  <div class="message binary">
    <span class="meta">
      <label class="channel">#{Message.formatDestination item}</label>
      <label class="from">#{Message.formatSource item}</label>
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
addcolor c for c in ['red','white','green','black','yellow','blue','grey']
Object.defineProperty String::, 'bold', get: -> '<b>' + @ + '</b>'

Message.formatSource = (item)->
  if peer = Peer.byCA[item.irac] then Peer.formatCA peer
  else if peer = Peer.bySA[item.irac] then Peer.format peer
  else htmlentities item.irac

Message.formatDestination = (item)-> item.tag.map( (i)-> switch i[0]
  when '@' then ( if sa = Peer.bySA[i.substr 1] then Peer.format sa else item.irac.substr(0,6) )
  when '#' then htmlentities i
  when '$' then htmlentities i
  else 'ILLEGAL-TAG ' + htmlentities i ).join ', '

Message.formatDestination = (item)-> item.tag.map Message.formatTag

Message.formatTag = (tag)->
  raw = tag.substr 1
  switch tag[0]
    when '@'
      if      ( ca = Peer.byCA[raw] ) then Peer.formatCA ca[0]
      else if ( sa = Peer.bySA[raw] ) then Peer.format sa
      else '@' + raw.substr(0,6).red
    when '#' then '#'.grey + raw.yellow
    when '$' then '$'.grey + raw.white
    else tag.red

Message.tagToClass = (tag)-> 'byTag_' + tag.replace('$','_dollar_').replace('@','_at_').replace('#','_hash_')
Message.getTags = (str)-> str.match(/^[#@$][a-zA-Z0-9_]+/g).unique.trim
Message.stripTags = (body,tags=[])->
  while tag = body.trim().match /^[#@$][a-zA-Z0-9_]+/
    tags.push tag[0]
    body = body.substr tag[0].length
  return [body,tags]
  str.match(/^[#@$][a-zA-Z0-9_]+/g).unique.trim

Message.text = (item)-> """
  <div class="message chat">
    <span class="meta">
      <label class="channel">#{Message.formatDestination item}</label>
      <label class="from">#{Message.formatSource item}</label>
      <label class="date">#{item.date}</label>
    </span>
    <p class="body chat">#{htmlentities item.body}</p>
  </div>
  """

Message.image = (item)-> """
  <div class="message chat image">
    <span class="meta">
      <label class="channel">#{Message.formatDestination item}</label>
      <label class="from">#{Message.formatSource item}</label>
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
      <label class="channel">#{Message.formatDestination item}</label>
      <label class="from">#{Message.formatSource item}</label>
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
      <label class="channel">#{Message.formatDestination item}</label>
      <label class="from">#{Message.formatSource item}</label>
      <label class="date">#{htmlentities item.date}</label>
    </span>
    <audio controls preload="none" src="/rpc/irac_get/#{item.hash}"></audio>
    <p class="body chat">#{htmlentities item.body}</p>
  </div>"""

Message.buddy = (item)-> """
  <div class="message peer byIrac_#{item.ra}">
    <span class="meta">
      <label class="from">#{Peer.formatCA item}</label>
      <label class="date">#{parseInt item.date}</label>
    </span>
  </div>"""

Message['x-irac'] = -> ''

Message.peer = (item)-> """
  <div class="message peer byIrac_#{htmlentities item.irac}">
    <span class="meta">
      <label class="from">#{Peer.format item}</label>
    </span>
  </div>
"""

Message.tag = (name)-> """
  <div class="message channel #{Message.tagToClass name}">
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
    @update opts
    Peer.bySA[opts.irac] = @
  update:(opts)->
    Object.assign @, opts
    return console.log 'NO-IRAC', @, opts unless @irac
    @channelName = '@' + @ra
    @peerName = '@' + @irac
    ca = Peer.byCA[opts.ra] || Peer.byCA[opts.ra] = []
    ca.push @
    ca.name = @caname
    unless ( c = $ '.byIrac_' + @ra ).length > 0
      $('#peer')[if peer.ra is $me.ra then 'prepend' else 'append'] c = $ Message.buddy @
      $(c.find('.from')[0]).on 'click', => View.set @channelName, @caname
    unless ( e = $ '.byIrac_' + @irac ).length > 0
      c.find('> .meta').append e = $ Message.peer @
      e.on 'click', => View.set @peerName, @name || @irac.substr(0,6)

Peer.handle = (item)->
  peer = item.seen || item.lost
  if sa = Peer.bySA[peer.irac]
    return if peer.lastUpdate > item.date
    sa.update peer
  else sa = new Peer peer
  return unless ( c = $ '.message.peer.byIrac_' + sa.irac ).length > 0
  if item.seen then c.removeClass 'offline'
  else c.addClass 'offline'
  lastUpdate = item.date
  null

Peer.lost = (peer)->
  true

Peer.formatCA = (peer)->
  return [' ','<i class="fa fa-users"></i>'.blue,' ',(peer.caname || 'me')].join '' if peer.ra is $me.ra
  if peer.caname then '<i class="fa fa-users"></i> ' + peer.caname
  else
    ( o = [] ).push ( peer.ia    || 'XX' ).substr(0,2).blue.bold
    o.push ( peer.ra    || 'XX' ).substr(0,2).green.bold
    o = o.join ''

Peer.format = (peer)->
  return Peer.formatCA peer if peer.irac is peer.ra
  return ' NULL '.error unless peer
  return [' ','<i class="fa fa-user"></i>'.blue,' ',(peer.name||'here')].join '' if peer.irac is $me.irac
  return [' ','<i class="fa fa-user"></i>'.white,' ',peer.name].join '' if peer.name
  o = []
  o.push ( peer.onion || 'XX' ).substr(0,2).red.bold
  o.push ( peer.irac  || 'XX' ).substr(0,2).red.bold
  o.push ( peer.ia    || 'XX' ).substr(0,2).blue.bold
  o.push ( peer.ra    || 'XX' ).substr(0,2).green.bold
  # o = o.concat ['[',peer.name.substr(0,6).green.bold,']'] if peer.name
  o = o.join ''
  if peer.group
    o += '[' + ACL.highest(peer.group).white.bold + ']'
  if peer.address
    o + '[' + ( if peer.address is peer.irac then DIRECT[peer.address] || "n/a" else peer.address ).yellow.bold + ']'
  else o










window.View = class View
  @setting: '$all'
  @update:(opts)->
    for tag in opts.tag when not ( c = $ '.' + Message.tagToClass tag ).length > 0
      continue if tag[0] is '@'
      $('#channel').append c = $ Message.tag tag
      c.on 'click', View.set.bind View, tag, tag
  @render:->
    return if @tick; @tick = true
    requestAnimationFrame @realRender
  @realRender:=>
    $('#feed').html ''
    list = Message.byTag[@setting] || []
    if @setting[0] is '@'
      if @setting is '@' + $me.irac
        list = list.concat(Message.byIRAC[$me.irac]||[]).sort View.sortNormal
      else list = list.concat(Message.byIRAC[@setting.substr 1]||[]).sort View.sortNormal
    for item in list
      t = if item.type then item.type.split('/')[0] else 'default'
      $('#feed').prepend i = ( Message[t] || Message.default )(item,@setting)
    $("#curchannel").html(@setname||@setting)
    $("#actions").html('').append """
      <i message-type="chat"  class="fa fa-envelope"></i>
      <i message-type="achat" class="fa fa-microphone"></i>
      <!--i message-type="vchat" class="fa fa-video-camera"></i-->
      <i message-type="ftp"   class="fa fa-file"></i>
      <i message-type="settings"   class="fa fa-cog"></i> """
    $('#actions .fa').each (k,e)=>
      e = $ e;
      e.off()
      e.on 'click', Peer.message[e.attr('message-type')].bind null, @setting, true
    do applyDate
    @tick = false
  @set:(setting,@setname,prompt,@callback)->
    @setting = setting
    $('#send').html if prompt then prompt else if @setting is '$all' then 'Publish Status' else 'Send to #' + @setting
    @onSend = =>
      unless '' is v = $("#input").val().trim()
        if v[0] is '/'  then request cmd = v.substr(1).split /[ \t]+/
        else if ( c = @callback ) then c v
        else request ['say',( if @setting is '$all' then '$status' else @setting ), v]
      $("#input").val('')
    View.render()
    null
  @sortNormal: (a,b)-> parseInt(a.date) - parseInt(b.date)

window.Prompt = class Prompt
  @modal:no
  close:-> @frame.remove(); Prompt.modal = no; $(document).off 'click', @close

class Prompt.Text extends Prompt
  constructor:(opts)->
    Prompt.modal.close() if Prompt.modal
    Prompt.modal = @
    Object.assign @, opts
    $('body').append @frame = $ """
      <div class="message prompt floating">
        <h1>#{@query}</h1>
        <input type="text"/>
        <button class="ok">OK</button>
        <button class="cancel">Cancel</button>
      </div>
    """
    @frame.find('input').val(@default) if @default
    @frame.find('input').focus()
    @frame.find('.ok').click => ( @callback || -> )(@frame.find('input').val()); @close()
    @frame.find('.cancel').click @close.bind @
    return

View.Proxy = (opts)->
  View.Proxy.count = ( View.Proxy.count || 0 ) + 1
  Object.assign @, opts
  unless @box = View.Proxy.box
    $('navigation').prepend @box = View.Proxy.box = $ """
    <div class="message floating" id="proxies"></div>"""
  @box.append @frame = $ """
    <span class="proxy">
      <i class="fa fa-#{@icon}"></i>
      #{@text}
    </span>
  """
  @remove = =>
    @frame.remove()
    @box.remove() if 0 is --View.Proxy.count
  if @click then @frame.click @click
  else @frame.click @remove
  return @















Peer.message.settings = (key)->
  switch key[0]
    when '@'
      if ( peer = Peer.byCA[hash = key.substr 1] ) then type = 'ca'
      else if ( peer = Peer.bySA[hash] )           then type = 'peer'
      else return false
    when '$' then type = 'meta'
    when '#' then type = 'channel'
    else console.log 'unknown', key
  menu = new ContextMenu type, hash || key

window.ContextMenu = class ContextMenu
  constructor:(@type,@key)->
    ContextMenu.instance.frame.remove() if ContextMenu.instance
    ContextMenu.instance = @
    @item = []
    $('body').append @frame = $ """<ul class="menu floating"></ul>"""
    @addItem title:name, click:action, icon:Action.icon[name] for name, action of Action[@type]
    setTimeout ( => $(document).click @close ), 100
  close:=> @frame.remove(); ContextMenu.instance = no; $(document).off 'click', @close
  addItem:(opts)->
    @frame.append i = $ """
      <li class="item"> <i class="fa fa-#{opts.icon || 'cog'}"></i> #{opts.title} </li>
    """
    i.on 'click', => @close(); ( opts.click || -> )( @key )

window.Action =
  icon:rename:'edit'
  ca:rename:(item)-> new Prompt.Text
    query:'Enter a new CA_NAME for ' + item
    default: item[0].caname || ''
    callback:(v)->
      i.caname = v for i in Peer.byCA[item]
      request ['set', '@'+item+'.caname', v]
  peer:rename:(item)-> new Prompt.Text
    query:'Enter a new NAME for ' + item
    callback:(v)-> request ['set', '@'+item+'.name', Peer.bySA[item].name = v]







Peer.message.achat = (root)->
  audio.add root + " " + $("#input").val().trim()
  $("#input").val('')

window.audio = new class AudioChat
  init:(callback)->
    @count = 0
    constraints = window.constraints = audio:on, video:off
    navigator.mediaDevices.getUserMedia constraints
     .then (@stream)=> do callback if callback
     .catch (e)-> console.error e
  add: (body)->
    fnvhash = fnv body
    return @remove fnvhash if @[fnvhash] and @[fnvhash].stop
    return @init @add.bind @, body unless @stream
    @count++
    request ['rec',body,type:'audio/opus'], (@hash) =>
      @proxy = new View.Proxy
        icon: 'microphone'
        text: Message.getTags(body).map(Message.formatTag).join ', '
        click: => @remove fnvhash
      $('#status .actions>i.fa-microphone').css('backgroundColor','red')
      @[fnvhash] = rec = new MediaStreamRecorder @stream
      timer = null; rec.mimeType = 'audio/opus'
      cid = 0 ; rec.ondataavailable = (blob) =>
        reader = new FileReader
        reader.readAsArrayBuffer blob
        console.log 'clear'
        clearTimeout timer
        timer = setTimeout ( =>
          request ['cut',@hash] ), 2000
        reader.onloadend = =>
          request ['chunk',@hash,cid++,new Uint8Array reader.result]

        null
      rec.start 500
    @[fnvhash] = 1
  remove: (fnvhash)->
    @proxy.remove()
    try @[fnvhash].stop()
    delete @[fnvhash]
    @stream.stop() if --@count is 0

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
