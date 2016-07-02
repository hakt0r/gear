###

  * c) 2010-2015 Sebastian Glaser <anx@ulzq.de>

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

  # SSL/TLS and Certificate - Management

###

$static PEER: PEER = {}, CA: CA = {}

$app.on 'daemon', -> $app.peerStore = new Storage
  name: 'peer'
  revive: (data)->
    data.remote = data.remote || data.cert
    new Peer.Remote data
  preWrite:-> Object.keys(PEER).map (i)-> PEER[i].encodeCBOR()
  filter:(i)-> i.auth
  firstRead:-> $app.on 'sync', (q,defer)->
    $app.peerStore.write defer 'peers'

$static class Peer
  groups:(args...)->
    @group = @group || ['$public']
    @group = @group.concat args
    @group.slice().map (g)=> @group = @group.concat add if add = ACL.group[g]
    @group = Array.unique @group
  register:->
    return unless @irac
    do $app.sync
    PEER[@irac] = @
    return unless @ra
    l = CA[@ra] = CA[@ra] || list:[]
    l.list.push l[@irac] = @
    return
  encodeCBOR:->
    @log ' SAVE-PEER '.error, Object.keys @
    @


Peer::error = Peer::hardcore = Peer::verbose = Peer::debug = Peer::log = (args...)->
  console.log.apply console, [Peer.format(@)].concat args

class Peer.Remote extends Peer
  constructor:(cert,settings)->
    cert = ( settings = cert ).remote if cert and cert.remote
    direction = if cert.inbound then 'in' else 'out'
    @[k] = v for k,v of settings when v? if settings
    unless cert? and ( cert.raw or cert.substr ) and false isnt @parseCert cert
      console.error '  PEER WITHOUT IRAC-CERTIFICATE '.error, cert
      return false
    peer_exists = ( peer = PEER[@irac] )? and not peer.shadow
    if true is peer_exists and true is cert.authorized
      peer.onion = @onion if @onion
      # peer.log '  EXISTING-PEER '.ok, @cachain?
      return peer
    if cert.authorized # XXX and not @group
      @log  '  AUTO-PEER '.error, @irac
      signedGroup = cert.subject.OU.toString().replace /\$local/, '$host'
      @groups signedGroup
    else @groups '$public'
    do @register
    @verbose '  PEER '.log, cert.authorized
    Peer.sync @ if ACL.check @, '$peer'

  parseCert:(cert)->
    cert = @remote unless cert
    # try to parse an IRAC-cert
    sa_crt = ( if cert.substr then $pki.certificateFromPem cert else
      $pki.certificateFromAsn1 $forge.asn1.fromDer $forge.util.createBuffer cert.raw, 'raw' )
    @irac   = $irac sa_crt.publicKey
    @remote = $pki.certificateToPem sa_crt
    @onion  = sa_crt.subject.getField('O').value
    try
      @cachain = sa_crt.extensions.find( (i)-> i.name is 'subjectAltName').altNames.filter( (i)-> i.value.match /^irac_..\./ ).map( (i)-> i.value ).map($pki.pemCertificateFromPemURL)
      @ra = $irac $pki.certificateFromPem(@cachain[0]).publicKey
      @ia = $irac $pki.certificateFromPem(@cachain[1]).publicKey
    return false unless @irac? and @ia? and @ra?

  encodeCBOR:->
    @log ' SAVE-PEER '.error, Object.keys @
    @

class Peer.Shadow extends Peer
  shadow:true
  group:['$public']
  constructor:(opts)->
    return false
    return false unless opts.irac
    return peer if ( peer = PEER[opts.irac] )?
    Object.assign @, opts
    @ra = @ra || '00'
    console.log Peer.format(opts), ' SHADOW '.bolder
    PEER[@irac] = @
    Request.static @, ['irac_peer'], $nullfn
  toJSON:-> false
  encodeCBOR:-> false

Peer.fromSocket = (socket)->
  cert = socket.getPeerCertificate yes
  cert.inbound = socket.inbound
  cert.authorized = socket.authorized
  cert.authorizationError = socket.authorizationError
  if cert.issuerCertificate and cert.inbound then try opts = cachain:[
    $pki.certificateToPem $pki.certificateFromAsn1 $forge.asn1.fromDer $forge.util.createBuffer cert.issuerCertificate.issuerCertificate.raw, 'raw'
    $pki.certificateToPem $pki.certificateFromAsn1 $forge.asn1.fromDer $forge.util.createBuffer cert.issuerCertificate.raw, 'raw' ]
  peer = new Peer.Remote cert, opts
  # peer.log  '  NETWORK-PEER '.error, cert.issuerCertificate?, cert.inbound
  peer

Peer.format = (peer)->
  return ' NULL '.error unless peer
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
