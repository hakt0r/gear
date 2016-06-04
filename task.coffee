
$static $evented class Task
  @lastId: 0
  @icon: 'fa-server'
  type: 'task'
  temp: false
  log: []
  constructor: (id)->
    ##console.log 'new_process', id, @id
    $evented @
    if typeof id is 'object' then ( @[k] = v for k,v of id ) else @id = id
    @id = @id || @name || @task || @type
    @id = @id + '_' + Task.lastId++ if Task.all[@id]
    @url = 'task:' + @id
    Task.all[@id] = @
    Task.emit 'create', @
    # Index.push @
    @start() if @autostart
  destructor:->
    Task.emit 'destroy', @
    Task.all[@id] = null
  enable:  ->
  disable: ->
  start:   (callback=->)-> @_start(=> @emit 'start', callback null); @
  stop:    (callback=->)-> @_stop( => @emit 'stop' , callback null); @
  restart: (callback=->)-> @stop(  => @start => @emit 'restart'   ); @

Task.all = {}

$static class SignalBasedTask extends Task
  start: (callback=->)->
    @running (running)=>
      unless running
        @run (@instance)=> if @instance?
          @emit 'start', @filter.call @, @on = yes
      callback running
    @
  filter: => @
  sendSignal: (action,callback)=> callback(); @
  signal: (action,callback=->)=>
    @running (i)=> @sendSignal action, => @emit action, callback()
    @
  getLog:             => @log.join '\n' || 'no'
  ended:               => @emit 'stopped', @on = no;  @
  running:  (callback)=> callback @instance || false; @
  stop:     (callback)=> @signal 'stop',    callback; @
  kill:     (callback)=> @signal 'kill',    callback; @
  pause:    (callback)=> @signal 'pause',   callback; @
  continue: (callback)=> @signal 'continue',callback; @

$static class Interval extends SignalBasedTask
  constructor: (@timeout,opts={})->
    @callback = if typeof opts is 'object' then opts.callback else (c = opts; opts = {}; c)
    opts.id = "interval" unless opts.id?
    opts.temp = on       unless opts.temp?
    opts.name = 'fn'     unless opts.name?
    opts.autostart = on  unless opts.autostart?
    super opts
  run: (callback)=>
    callback setInterval (=> @callback.apply @), @timeout
    @
  sendSignal: (action,callback=->)=>
    if action is 'continue' then @start callback
    else callback @ended clearTimeout i
    @

$static class Process extends SignalBasedTask
  constructor: (opts={})->
    opts.id   = opts.name || opts.id || "process"
    opts.name = opts.name || opts.script
    opts.name = opts.command[0] if opts.command and not opts.name?
    opts.temp = on unless opts.temp?
    opts.autostart = on unless opts.autostart?
    super opts
  run: (callback)->
    if @command? or @script?
      if @command then i = $cp.spawn @command.slice(0,1)[0], @command.slice(1), @command.cp
      else if @script then i = $cp.spawn 'sh', @script
      callback $cp.sane( i ).on 'close', (status,signal='')=> @ended @log.push @id + ' ended: ' + status + ' ' + signal
    else callback null
    @
  sendSignal: (action,callback=->)->
    @instance.kill (stop:'SIGQUIT',kill:'SIGKILL',pause:'SIGINT',continue:'SIGCONT')[action] if @instance
    callback()
    @
  filter: ->
    @instance.on 'error', _ = (e)=> @log.push l for l in e.trim().split('\n')
    s.on 'data', _ for s in [@instance.stdout,@instance.stderr]
    @
