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

return unless $config.i3
return unless $require ->
  @apt mpstat:'sysstat'
  @apt nmap:'nmap', hostapd:'hostapd', 'aircrack-ng':'aircrack-ng'
  @npm 'ip','netroute','wireless-tools', 'pty.js'

$static $ip: require 'ip'

$ip.route    = require('netroute').getInfo
$ip.ifconfig = require 'wireless-tools/ifconfig'
$ip.iwconfig = require 'wireless-tools/iwconfig'
$ip.iwlist   = require 'wireless-tools/iwlist'

class StatusBar
  @plugin: {}
  @byKey: {}
  @list: []
  @update:->
    return unless @_updateTimer < t = Date.now()
    @_update @_updateTimer = t
  @_updateTimer: 0
  @_update:->
  @block: (key,opts)->
    index = @list.length
    index = Math.min after + 1, @list.length-1 if ( after  = opts.after  ) and ( after  = @byKey[after]  )
    index = Math.max before   , 0              if ( before = opts.before ) and ( before = @byKey[before] )
    index = 0                                  if opts.left
    run   = opts.run                           if opts.run
    timer = opts.timer                         if opts.timer
    StatusBar.click[key] = opts.click          if opts.click
    delete opts.after; delete opts.before; delete opts.left; delete opts.run; delete opts.timer; delete opts.click
    item = _.defaults opts, name:key,full_text:"<"+key+">",short_text:"<"+key+">",color:"#333333",urgent:false,separator:false,separator_block_width:10
    @execute.apply null, run                   if run
    if timer
      setInterval ( => @update timer[1] item ), timer[0]
      setTimeout  ( => @update timer[1] item ), 0
    @update @remap @list.splice index, 0, item
    item
  @remap:->
    @byKey = {}
    @list.map (i,k)=> @byKey[i.name] = k
  @hide: (item)->
    return if -1 is idx = @list.indexOf(item)
    @remap @list.splice idx, 1
  @execute: (cmd,callback)->
    inst = $cp.spawn cmd.shift(), cmd
    inst.stdout.setEncoding 'utf8'
    buf = ''
    inst.stdout.on 'data', (d)->
      buf += d
      while -1 < ( pos = buf.indexOf '\n' )
        callback buf.substr 0, pos
        buf  = buf.substr pos + 1
    inst



StatusBar.plugin.log = (bar)->
  log = timer = null
  digest = (line)->
    line = line.replace(/\x1b\[[0-9;]*m/g,'').substr(0,100)
    unless log
      log = StatusBar.block 'log', separator_block_width: 10, left:yes, full_text: line, color: '#FFFFFF'
    else log.full_text = line
    ( clearTimeout timer; timer = null ) if timer
    timer = setTimeout ( -> StatusBar.hide log; log = null ), 1000
  $sudo.read 'tail -f /var/log/syslog', (line)->
    digest line.split(/[ ]+/).slice(4).join(' ')
  $app.on 'log', (args...)-> digest args.join ' '
  null


StatusBar.click = {}
StatusBar.plugin.notice = (bar)->
  notice = {}
  _notice_block = (msg)-> StatusBar.block 'notice_' + msg.id,
    full_text: (msg.summary + ': ' + msg.body).substr(0,100)
    separator_block_width: 10
    left:yes
    color:'#ffffff'
  queue = $async.cue (msg,c)->
    notice[msg.id] = n = _notice_block msg
    setTimeout ( ->
      StatusBar.hide(n)
      notice[msg.id] = null
      c null
    ), t = Math.max(300, ( if queue.cue.length > 3 then 300 else msg.expire_timeout ))
    null
  $app.on 'notice', (msg)->
    if msg.expire_timeout is 0
      console.hardcore msg
      msg.click = msg.close unless msg.click?
      block = _notice_block msg
      msg.on 'close', ->
        delete StatusBar.click[block.name]
        StatusBar.hide block
      StatusBar.click[block.name] = (event)->
        msg.click event
    else queue msg
  $app.on 'notice:update', (msg)->
    return unless ( n = notice[msg.id] )
    # n.full_text = msg.summary + ': ' + msg.body
  null



StatusBar.plugin.cpu = (bar)->
  return unless $which 'mpstat'
  cpu = []
  temp = path: '/sys/devices/platform/coretemp.0/hwmon/hwmon0'
  for m in $fs.readdirSync('/sys/devices/system/cpu').filter( (i)-> null isnt i.match /^cpu[0-9]+$/ ).map( (i)-> parseInt i.replace(/cpu/,'') )
    StatusBar.click[ 'cpu_' + m ] = ( (m)-> ->
        v = ( ( parseInt $fs.readFileSync "/sys/devices/system/cpu/cpu#{m}/online", 'utf8' ) + 1 ) % 2
        $sudo.script "echo #{v} > /sys/devices/system/cpu/cpu#{m}/online", $nullfn )( m )
  if $fs.existsSync temp.path
    for file in $fs.readdirSync temp.path when file.match /_label$/
      name = file.replace /_label$/, ''
      l = $fs.readFileSync $path.join(temp.path,file), 'utf8'
      unless null is ( m = l.trim().match /Core[ \t]+([0-9]+)$/ )
        temp[ id = 'cpu_' + m[1] ] =
          path:                      $path.join(temp.path,name+'_input')
          critical: parseInt $fs.readFileSync( $path.join(temp.path,name+'_crit'), 'utf8') / 1000
          alarm:    parseInt $fs.readFileSync( $path.join(temp.path,name+'_crit_alarm'), 'utf8') / 1000
  StatusBar.execute ['mpstat','-P','ALL','1'], (line)->
    line = line.split /[ \t]+/
    unless Number.isNaN( id = parseInt line[2] ) or Number.isNaN( usr = parseInt line[3] ) or Number.isNaN( sys = parseInt line[5] )
      unless ( c = cpu[id] )
        cpu.map (item)-> item.item.separator_block_width = 5
        c = cpu[id] =
          value: xid = 'cpu_' + id
          item: StatusBar.block xid,
            before: 'bat'
            separator_block_width: 3
          temp: temp[xid]
      perc = ( usr + sys ).toString()
      c.value = ''
      if perc > 0
        c.value += if perc.length is 1 then '0' + perc else perc
      if c.temp then try
        t = parseInt($fs.readFileSync(c.temp.path,'utf8'))/1000
        c.value += if t.length is 1 then '0' + t else t
        perc = p if 75 < p = t / c.temp.critical
      cl = Math.max( 100, parseInt 2.55 * parseInt perc ).toString 16
      cl = '0' + cl if cl.length is 1
      if perc > 74
        c.item.color = '#' + cl + '0000' #cl + cl
      else
        c.item.color = '#00' + cl + '00' #cl + cl
      c.item.full_text = c.value
  null



StatusBar.plugin.disk = (bar)->
  StatusBar.block 'disk',
    separator_block_width: 3
    timer: [10000, (item)->
      $cp.exec 'df -P ' + process.env.HOME, (e,m)->
        perc = parseInt m.split('\n')[1].split(/[ ]+/)[4]
        item.full_text = '' + perc
        c = Math.max( 33, parseInt 2.55 * parseInt perc ).toString 16
        c = '0' + c if c.length is 1
        item.color = '#00' + c + '00'
        item.color = '#' + c + '0000' if perc > 75 ]
  null



StatusBar.plugin.swap = (bar)->
  swap = null
  StatusBar.block 'mem',
    separator_block_width: 3
    timer: [1000, (item)->
      mem = $fs.readFileSync('/proc/meminfo','utf8')
      free   = mem.match(/MemFree:[ ]+([0-9]+)/)[1]
      total  = mem.match(/MemTotal:[ ]+([0-9]+)/)[1]
      perc   = parseInt( ( free / total ) * 100 )
      item.color = '#00FF00'
      c = Math.max( 33, parseInt 2.55 * parseInt perc ).toString 16
      c = '0' + c if c.length is 1
      item.color = '#00' + c + '00'
      item.color = '#FF0000' if perc < 20
      item.full_text = '' + perc
      sfree  = mem.match(/SwapFree:[ ]+([0-9]+)/)[1]
      stotal = mem.match(/SwapTotal:[ ]+([0-9]+)/)[1]
      perc   = parseInt( ( sfree / stotal ) * 100 )
      return StatusBar.hide swap if perc is 100 or perc.toString() is 'NaN'
      swap.color = '#00FF00'
      swap.color = '#FF0000' if perc < 20
      swap.full_text = '' + perc
    ]
  swap = StatusBar.block 'swap',
    separator_block_width: 3
  null

StatusBar.click.mem = -> $sudo.script 'free && sync && echo 3 > /proc/sys/vm/drop_caches && free', $nullfn
StatusBar.click.swap = -> $sudo.script 'swapoff -a', $nullfn




StatusBar.plugin.net = (bar)->
  visible = {}
  dev = {}
  net = $os.networkInterfaces()
  update = (n,d)->
    id   = 'net_' + n
    text = n
    color = '#999999'
    if d.ssid
      color = '#00FF00'
      text = d.ssid
    if net[d.interface] and net[d.interface][0] and net[d.interface][0].address
      text += '\uf1eb' + net[d.interface][0].address
    unless ( b = d.block )
      d.block = StatusBar.block id, separator_block_width: 3, full_text: text, before: 'bat', color
    else b.full_text = text; b.color = color
  setInterval ( ->
    net = $os.networkInterfaces()
    $ip.ifconfig.status (error,devices)->
      devices.map (d)->
        return unless d.up
        d.interface = d.interface.replace /:$/, '' # FIXME UPSTREAM
        return d.interface is 'lo'
        if dev[d.interface]?
          dev[d.interface] = _.defaults d, dev[d.interface]
        else dev[d.interface] = d
    $ip.iwconfig.status (error,devices)->
      devices.map (d)->
        if dev[d.interface]
          dev[d.interface] = _.defaults d, dev[d.interface]
        else dev[d.interface] = d
    update k,d for k,d of dev
  ), 1000
  null

StatusBar.plugin.time = (bar)->
  StatusBar.block 'time',
    separator_block_width:3
    color: "#FFFF00"
    click:->
      s = require('net').createServer (c)->
        c.on 'data', -> console.hardcore arguments
        c.write '\x1b[42m heelo !'
      sock = $path.join $path.configDir, 'menu-socket'
      $fs.unlinkSync sock if $fs.existsSync sock; s.listen sock
      i = $cp.spawn 'stterm', ['-l',sock,'raw']
      i.on 'close', -> s.close()
    timer: [1000, (item)->
      d = new Date
      H =  d.getHours().toString()
      M =  d.getMinutes().toString()
      S =  d.getSeconds().toString()
      y =  d.getFullYear().toString()
      m = (d.getMonth() + 1).toString()
      d =  d.getDate().toString()
      date = y + (if m[1] then m else '0' + m[0]) + (if d[1] then d else '0' + d[0])
      date += '|' + (if H[1] then H else '0' + H[0]) + (if M[1] then M else '0' + M[0]) + (if S[1] then S else '0' + S[0])
      item.full_text = date ]
  null

battlevel = ['','','','',''] # requires fontawesome
# if $fs.existsSync '/sys/class/power_supply/ADP1' and $fs.existsSync '/sys/class/power_supply/BAT1'
StatusBar.plugin.bat = (bar)-> StatusBar.block 'bat',
  before:'time'
  separator_block_width: 3
  click:-> $cp.spawn 'xterm',['-e','sudo','powertop','--auto-tune']
  timer: [ 1000, (item)-> ac_res = dc_cap = dc_wat = null; $async.parallel [
    (c)-> $fs.readFile '/sys/class/power_supply/ADP1/online',    'utf8', (error,result)-> c error, ac_res = result
    (c)-> $fs.readFile '/sys/class/power_supply/BAT1/capacity',  'utf8', (error,result)-> c error, dc_cap = result
    (c)-> $fs.readFile '/sys/class/power_supply/BAT1/power_now', 'utf8', (error,result)-> c error, dc_wat = result
  ], ->
    ac = 1 is parseInt ac_res; perc = parseInt dc_cap; watt = ( 0.000001 * parseInt dc_wat ).toFixed(1)
    item.color = '#00FF00'
    item.color = '#FFFF00' unless ac
    item.color = '#FF0000' if perc < 20
    item.full_text = battlevel[ Math.round perc / 25 ] + ( if ac then '' else perc + '' + watt ) ]

StatusBar.plugin.tools = (bar)->
  StatusBar.block 'restart', separator_block_width:3, color: "#FFFF00", full_text: '', click: -> $app.cli.restart()
  StatusBar.block 'volume',  separator_block_width:3, color: "#FFFF00", full_text: '', click: -> $cp.spawn 'pavucontrol',[]
  pm = StatusBar.block 'desktop_mode',  separator_block_width:3, color: "#FFFF00", full_text: '', click: ->
    switch pm.full_text
      when '' # laptop mode -> switch to desktop
        pm.full_text = ''; radio.full_text = ''
        $sudo.script """
          /home/anx/bin/attach_hdmi &
          nmcli radio wifi on &
          echo 7812 > /sys/class/backlight/intel_backlight/brightness
          echo 1 > /sys/devices/system/cpu/cpu1/online
        """, $nullfn
      when '' # desktop mode -> switch to laptop
        pm.full_text = ''; radio.full_text = ''
        $sudo.script """
          /home/anx/bin/attach_hdmi &
          nmcli radio wifi off &
          # powertop --auto-tune &
          echo 1000 > /sys/class/backlight/intel_backlight/brightness
          echo 0 > /sys/devices/system/cpu/cpu1/online
        """, $nullfn
  radio = StatusBar.block 'radio',  separator_block_width:3, color: "#FFFF00", full_text: '', click: ->
    switch radio.full_text
      when '' then radio.full_text = ''; $sudo.script """nmcli radio wifi on""", $nullfn
      when '' then radio.full_text = ''; $sudo.script """nmcli radio all off""", $nullfn

$app.on 'daemon', ->
  path = $path.join $path.configDir, 'bin', 'gear-bar'
  sock = $path.join $path.configDir, 'bar-socket'
  $fs.unlinkSync sock if $fs.existsSync sock
  $fs.writeFileSync path,"""
  #!/bin/sh
  ncat -U '#{sock}'
  """
  $cp.spawn 'chmod', ['a+x',path]
  $app.barSocket = s = require('net').createServer (c)->
    $carrier.carry c, (line)-> unless line is '[' then try
      event = JSON.parse line.replace /^,/,''
      handler event if ( handler = StatusBar.click[event.name] )
      null
    c.write """
    {"version":1,"click_events":true}
    [[]
    ,[{"full_text":"gear:: starting"}]
    """
    do StatusBar._update = ->
      c.write ',' + JSON.stringify StatusBar.list
    c.on 'error', -> c.end()
  s.on 'error', ->
  s.listen sock
  $cp.spawn 'chmod', ['666',sock]
  null

$app.on 'daemon', -> if $which 'i3'
  for k,v of StatusBar.plugin
    # console.log "StatusBar:plugin", k
    v()
  # console.debug Object.keys StatusBar.plugin
  $cp.spawn 'i3',['restart'] if $which 'i3'
  $cp.spawn 'killall',['dunst','xfce4-notifyd']
