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

if $path?
  unless $fs.existsSync $path.backend = $path.join $path.bin, 'gear-daemon'
    $fs.writeFileSync $path.backend, """
    #!#{$which 'nodejs' || $which 'node'}
    require('#{$path.join $path.cache, 'gear.js'}');"""
    $fs.chmodSync $path.backend, '755' if $fs.chmodSync
  # unless $fs.existsSync 
  $path.client = $path.join $path.bin, 'gear'
  $fs.writeFile $path.client, $fs.readFileSync __filename
  $fs.chmodSync $path.client, '755' if $fs.chmodSync
  return

path = require 'path'
fs = require 'fs'
https = require 'https'

DIR  = path.join path.dirname(__dirname), 'ca'
CA   = path.join DIR, 'ca.pem'
ICA  = path.join DIR, 'intermediate_ca.pem'
KEY  = path.join DIR, 'me.pem'
CERT = path.join DIR, 'me.crt'
CHN  = [ fs.readFileSync(CA,'utf8'), fs.readFileSync(ICA,'utf8') ]

args = process.argv
break for a,i in args = process.argv when path.basename(a) is 'gear'
args = args.slice i+1

body = new Buffer JSON.stringify args

request = https.request {
  method:'POST'
  host:'localhost'
  port:2003
  path:'/rpc'
  rejectUnauthorized:yes
  ca: CHN
  key:  fs.readFileSync KEY
  cert: fs.readFileSync CERT
  headers:
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength body
}, (res)->
  buffer = []
  res.on 'data', (data)-> buffer.push data.toString()
  res.on 'error',  (data)->
    console.error 'socket_error:', data # unless 0 is args.indexOf 'stop'
  res.on 'end',  (data)->
    d = buffer.join ''
    process.exit 0 if d is ''
    d = JSON.parse d
    process.exit 1 if d is false
    if Array.isArray d
      console.log d.join '\n'
    else console.log d

request.end body
