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
  @npm 'express','ws','compression','morgan','body-parser','serve-static'
  @mod 'auth'

$config.web  = $config.web  || port:2003
$config.meta = $config.meta || {}
$static $web: require('express')()

$web.static = require('serve-static')($path.shared,setHeaders:(res,fullpath)->
  res.setHeader 'X-Powered-By', 'irac/express/nodejs'
  return unless meta = $config.meta[path = $path.basename fullpath]
  console.log 'HEADERS'.whiteBG.black.bold, path, meta.type
  res.setHeader 'Content-Type', meta.type || 'application/octet-stream'
  res.setStatus 200 unless IRACStream.byHash[path] )

$web.bindCoffee = (path,source)->
  $web.get path, (req,res)->
    res.setHeader('Content-Type','text/javascript')
    res.send $coffee.compile $fs.readFileSync( $path.join($path.modules,source), 'utf8')
  $web

$web.bindLibrary = (path,source,mime='text/javascript',filter)->
  $web.get path, (req,res)->
    res.setHeader('Content-Type',$cache.get 'mime_'+source)
    res.send $cache.get source
  return if ( cache = $cache.get source ) and ( mime = $cache.get 'mime_' + source )
  console.log ( cache = source + ' DOWNLOADING ' ).warn
  $request.get source, (error,req,body)->
    body = filter.apply @, arguments if filter?
    return console.error "BIND-LIBRARY", source, error if error
    $cache.add source, cache = body
    $cache.add 'mime_' + source, mime = req.headers['content-type']
    console.log ' FINISHED '.ok, $path.basename(source), body.substr(0,10).blue.inverse
    console.log $cache.get(source).substr(0,10).blue.inverse
    console.log $cache.get('mime_'+source).substr(0,10).blue.inverse
  $web

$web.REPLY = (rx,tx)->
  (results)-> tx.end JSON.stringify results

$app.on 'daemon', ->
  console.debug ' WEB-START '.ok, $config.web
  $web.https = require('https').createServer(
    requestCert: yes
    rejectUnauthorized: no
    ca:   $auth.cachain
    key:  $auth.pem
    cert: $auth.cert )
  WebSocketServer = require('ws').Server
  $web.wss = new WebSocketServer server:$web.https
  $web.https.on 'request', (req,res)->
    req.client.inbound = yes
    if false is req.peer = res.peer = Peer.fromSocket req.client
      console.log ' HTTP-REJECT '.error
      return res.end ''
    return $web.apply @, arguments
  $web.use do require('compression') unless $config.web.disableCompression
  $web.use do require('body-parser').json
  $web.use require('morgan') 'combined', stream: process.stderr if $config.web.log
  $web.https.listen $config.web.port, ( (err)-> console.error 'http', err if err )
  $app.emit 'web:listening'

$app.on 'web:listening', -> $web.get '/rpc/*', (rx,tx,nx)->
  args = ( v for k,v of rx.params["0"].split('/') )
  do args.pop if args[ l = args.length - 1 ] is ''
  if args[ l - 1 ][0] is '{' then try
    opts = JSON.parse decodeURIComponent args[l]
    do args[l] = opts # this will enact opts no nee for a catch
  peer = rx.peer
  # console.hardcore 'GET-RPC', typeof args, $util.inspect args
  new $rpc.scope web:{req:rx,res:tx,next:nx}, group:peer.group, peer:peer, cmd:args, reply:$web.REPLY rx,tx

$app.on 'web:listening', -> $web.post '/rpc', (rx,tx,nx)->
  peer = rx.peer
  # peer.hardcore  'POST-RPC', typeof rx.body, $util.inspect rx.body
  new $rpc.scope web:{req:rx,res:tx,next:nx}, group:peer.group, peer:peer, cmd:rx.body, reply:$web.REPLY rx,tx

$app.emit 'web:start'
