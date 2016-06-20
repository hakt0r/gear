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

return unless $require ->
  @defer()
  @apt certutil: 'libnss3-tools'
  @npm 'node-forge'

setImmediate ->
  $static $auth: new Peer.CA
  do $require.Module.byName.auth.resolve

$app.on 'daemon', ->
  console.log ' IRAC '.blue.bold.inverse, Peer.format($config.hostid)
  for i,p of $config.peers when i isnt $config.hostid.irac
    delete $config.peers[i]
    new Peer.Remote p
  null

$static PEER: $config.peers = $config.peers || {}

{ tls, asn1, pkcs12, pki, md } = forge = $require 'node-forge'
{ md5, sha1, sha256, sha512 }   = md
{ rsa } = pki

pki.pemCertificateToPemURL = (cert,proto='irac') -> proto + '.' + cert.replace(/[\r\n]/g,'').replace(/-----[A-Z ]+-----/g,'')
pki.pemCertificateFromPemURL = (url) -> '-----BEGIN CERTIFICATE-----\r\n' + url.replace(/^[^.]+\./,'') + '\r\n-----END CERTIFICATE-----'
pki.certificateToPemURL = (cert,proto='irac') -> pki.pemCertificateToPemURL pki.certificateToPem(cert), proto
pki.certificateFromPemURL = (url) -> pki.certificateFromPem pki.pemCertificateFromPemURL url

$static
  $pki: pki
  $rsa: rsa
  $md5:    (str)-> md5.create(   ).update(str).digest().toHex()
  $sha1:   (str)-> sha1.create(  ).update(str).digest().toHex()
  $sha256: (str)-> sha256.create().update(str).digest().toHex()
  $sha512: (str)-> sha512.create().update(str).digest().toHex()
  $sha1r:  (str)-> sha1.create(  ).update(str).digest()
  $B32: (plain)->
    charTable = 'abcdefghijklmnopqrstuvwxyz234567'
    shiftIndex = digit = i = 0
    plain = new Uint8Array(plain)
    encoded = ''
    while i < plain.length
      current = plain[i]
      if shiftIndex > 3
        digit = current & 0xff >> shiftIndex
        shiftIndex = (shiftIndex + 5) % 8
        digit = digit << shiftIndex | (if i + 1 < plain.length then plain[i + 1] else 0) >> 8 - shiftIndex
        i++
      else
        digit = current >> 8 - ( shiftIndex + 5 ) & 0x1f
        shiftIndex = ( shiftIndex + 5 ) % 8
        i++ if shiftIndex is 0
      encoded += charTable[digit]
    encoded
  $onion: (key=false)->
    if key is false
      key = rsa.generateKeyPair bits: 1024, e: 0x10001
      key.pem = pki.privateKeyToPem key.privateKey
    else if typeof key is 'string'
      key = publicKey: pki.publicKeyFromPem key
    key.onion      = $B32( new Buffer pki.getPublicKeyFingerprint(key.publicKey).data, 'binary' ).substr(0,16)
    key.pem_public = pki.publicKeyToPem key.publicKey
    key
  $irac: (key)->
    key = key || $auth.cakey.publicKey
    $B32 new Buffer pki.getPublicKeyFingerprint(key,md:sha256.create()).data, 'binary'

$static class ACL
  @group:
    $local:  ['$public','$peer','$buddy','$host']
    $host:   ['$public','$peer','$buddy']
    $buddy:  ['$public','$peer']
    $peer:   ['$public']
    $public: []
  @check: (target,group...)->
    return false unless has = target.group
    return true  for g in group when -1 isnt has.indexOf g
    false
  @highest:(groups)->
    return g for g,v of ACL.group when -1 isnt groups.indexOf g
    return '$public'

$static class Peer
  groups:(args...)->
    @group = @group || ['$public']
    @group = @group.concat args
    @group.slice().map (g)=> @group = @group.concat add if add = ACL.group[g]
    @group = Array.unique @group
  register:->
    return unless @irac
    do $app.sync
    Peer.byIRAC[@irac] = @
    return unless @ra
    l = Peer.byCA[@ra] = Peer.byCA[@ra] || list:[]
    l.list.push l[@irac] = @
    return

Peer::hardcore = Peer::verbose = Peer::debug = Peer::log = (args...)->
  console.log.apply console, [Peer.format(@)].concat args

Object.defineProperty Peer::, 'auth', get:->
  ra:@ra,ia:@ia,irac:@irac,onion:@onion,remote:@remote,cert:@cert,cachain:@cachain,group:@group

class Peer.Shadow extends Peer
  shadow:true
  group:['$public']
  constructor:(opts)->
    return peer if ( peer = PEER[opts.irac] )?
    Object.assign @, opts
    return false unless @irac
    Request.static @, ['irac_peer',$config.hostid.cachain], $nullfn
    PEER[@irac] = @
  toJSON:-> false
  toBSON:-> false

class Peer.Remote extends Peer
  constructor:(cert,settings)->
    cert = ( settings = cert ).remote if cert and cert.remote
    direction = if cert.inbound then 'in' else 'out'
    @[k] = v for k,v of settings when v? if settings
    unless cert? and ( cert.raw or cert.substr )
      console.error '  PEER WITHOUT CERTIFICATE '.red.bold.inverse
      return false
    if false is @parseCert cert
      console.error '  PEER WITHOUT IRAC-CERTIFICATE '.red.bold.inverse, cert
      return false
    if ( peer = PEER[@irac] )?
      peer.onion = @onion if @onion
      peer.log '  EXISTING-PEER '.red.bold.inverse, @cachain?
      return peer
    if cert.authorized # XXX and not @group
      @log  '  AUTO-PEER '.red.bold.inverse, @irac
      signedGroup = cert.subject.OU.toString().replace /\$local/, '$host'
      @groups signedGroup
    else @groups '$public'
    do @register
    @verbose '  PEER '.blue.bold.inverse, cert.authorized
    Peer.sync @ if ACL.check @, '$peer'

  parseCert:(cert)->
    cert = @remote unless cert
    # try to parse an IRAC-cert
    sa_crt = ( if cert.substr then pki.certificateFromPem cert else
      pki.certificateFromAsn1 asn1.fromDer forge.util.createBuffer cert.raw, 'raw' )
    @irac   = $irac sa_crt.publicKey
    @remote = pki.certificateToPem sa_crt
    @onion  = sa_crt.subject.getField('O').value
    try
      @cachain = sa_crt.extensions.find( (i)-> i.name is 'subjectAltName').altNames.filter( (i)-> i.value.match /^irac_..\./ ).map( (i)-> i.value ).map(pki.pemCertificateFromPemURL)
      @ra = $irac pki.certificateFromPem(@cachain[0]).publicKey
      @ia = $irac pki.certificateFromPem(@cachain[1]).publicKey
    return false unless @irac? and @ia? and @ra?
    @log  '  PEER '.white.bold.inverse, @cachain?, PEER[@irac]?

Peer.fromSocket = (socket)->
  cert = socket.getPeerCertificate yes
  cert.inbound = socket.inbound
  cert.authorized = socket.authorized
  cert.authorizationError = socket.authorizationError
  if cert.issuerCertificate and cert.inbound then try opts = cachain:[
    pki.certificateToPem pki.certificateFromAsn1 asn1.fromDer forge.util.createBuffer cert.issuerCertificate.issuerCertificate.raw, 'raw'
    pki.certificateToPem pki.certificateFromAsn1 asn1.fromDer forge.util.createBuffer cert.issuerCertificate.raw, 'raw' ]
  peer = new Peer.Remote cert, opts
  peer.log  '  NETWORK-PEER '.red.bold.inverse, cert.issuerCertificate?, cert.inbound
  peer

class Peer.CA extends Peer
  group:  ['$local']
  direct: yes
  myself: yes
  constructor:->
    Object.assign @, $config.hostid || {}
    $config.hostid = @
    @serial = @serial || 0
    do @setupFiles
    do @setupCA
    @cachain = [
      pki.certificateToPem @ca
      pki.certificateToPem @intermediate_ca ]
    Object.assign @, do @setupKeys
    do @installKeys
    do @register
    Object.freeze(@group)

$static PEER: Peer.byIRAC = $config.peers

Peer.byCA = {}

Peer.format = (peer)->
  return ' NULL '.red.bold.inverse unless peer
  o = []
  o = o.concat ['[',peer.name.substr(0,6).green.bold,']'] if peer.name
  o.push ( peer.irac  || 'XX' ).substr(0,2).yellow.bold
  o.push ( peer.ia    || 'XX' ).substr(0,2).blue.bold
  o.push ( peer.ra  || 'XX' ).substr(0,2).green.bold
  o.push ( peer.onion || 'XX' ).substr(0,2).white.bold
  o = o.join ''
  if peer.group
    o += '[' + ACL.highest(peer.group).white.bold + ']'
  if peer.address
    o + '[' + ( if peer.address is peer.irac then DIRECT[peer.address] || "n/a" else peer.address ).yellow.bold + ']'
  else o

Peer.CA::setupKeys = (host='me')-> # onion / server / client key - package
  exports = {}
  unless $fs.existsSync path = $path.ca host+'_onion.pem'
    o = do $onion
    $fs.writeFileSync path, o.pem
    $fs.writeFileSync $path.ca(host+'_onion.pub'), o.pem_public
  else o = $onion $fs.readFileSync $path.ca(host+'_onion.pub'), 'utf8'
  exports.onion = o.onion
  unless $fs.existsSync path = $path.ca host+'.pem'
    exports.key = rsa.generateKeyPair bits: 1024, e: 0x10001
    $fs.writeFileSync path, pki.privateKeyToPem exports.key.privateKey
    console.log ' HOST '.green.bold.inverse, host, $irac exports.key.publicKey
  else exports.key =
    privateKey: privateKey = pki.privateKeyFromPem $fs.readFileSync(path,'utf8')
    publicKey:  publicKey  = pki.setRsaPublicKey privateKey.n, privateKey.e
    modulus: publicKey.n.toString(16).toUpperCase()
  unless $fs.existsSync path = $path.ca host+'.crt' # certificate / pem
    exports.irac = $irac exports.key.publicKey
    cert = pki.createCertificate()
    cert.signatureOid = pki.oids['rsaEncryption']
    cert.publicKey    = exports.key.publicKey
    cert.serialNumber = '0x' + ( ++$config.hostid.serial ).toString 16
    cert.validity.notBefore = new Date
    cert.validity.notAfter  = new Date
    cert.validity.notAfter.setFullYear cert.validity.notBefore.getFullYear() + 1
    cert.setIssuer @intermediate_ca.subject.attributes
    cert.setSubject @attrs exports.irac.substr(0,6) + '.', @ra, (if host is 'me' then '$local' else '$host'), exports.onion
    cert.setExtensions [
      { name: 'extKeyUsage', serverAuth:  true, clientAuth: true, timeStamping: true }
      { name: 'subjectAltName', altNames: [
        { type: 2, value: exports.irac.substr(0,6) + '.' + @ra + '.irac' }
        { type: 2, value: exports.irac }
        { type: 2, value: exports.onion }
        { type: 2, value: 'irac' }
        { type: 2, value: 'localhost' }
        { type: 2, value: pki.certificateToPemURL @ca, 'irac_ca' }
        { type: 2, value: pki.certificateToPemURL @intermediate_ca, 'irac_ia' }
        { type: 7, ip: '127.0.0.1' } ] } ]
    cert.sign @intermediate_key.privateKey, sha256.create()
    $fs.writeFileSync path, exports.cert = pki.certificateToPem cert
  else exports.cert = $fs.readFileSync path, 'utf8'
  unless $fs.existsSync path = $path.ca(host+'.p12') # certificate / pkcs12 - for browsers
    p12 = pkcs12.toPkcs12Asn1 exports.key.privateKey, [exports.cert,@ca], '', algorithm:'3des'
    $fs.writeFileSync path, new Buffer asn1.toDer(p12).getBytes(), 'binary'
  exports.irac = $irac exports.key.publicKey
  exports.ia = @ia
  exports.ra = @ra
  exports.pem = pki.privateKeyToPem exports.key.privateKey
  exports

Peer.CA::createHost = (hostname,address)->
  exports = @setupKeys hostname
  exports.remote = exports.cert
  exports.group = ['$host']
  exports.name = hostname
  exports.caname = $auth.caname
  exports.address = address
  delete exports.cert
  delete exports.key
  delete exports.pem
  new Peer.Remote exports

Peer.CA::authorize = (peer, group='$peer')->
  return false if @caDisabled
  { irac, ia, root, onion, remote } = peer
  cert = pki.createCertificate()
  cert.publicKey = pki.certificateFromPem(remote).publicKey
  cert.serialNumber = '0x' + ( ++$config.hostid.serial ).toString 16
  cert.validity.notBefore = new Date
  cert.validity.notAfter  = new Date
  cert.validity.notAfter.setFullYear cert.validity.notBefore.getFullYear() + 1
  cert.setSubject @attrs '', irac, group, peer.onion
  cert.setIssuer @intermediate_ca.subject.attributes
  cert.setExtensions [
      { name: 'keyUsage', keyCertSign: no, digitalSignature: true, nonRepudiation: true, keyEncipherment: true, dataEncipherment: true }
      { name: 'extKeyUsage', serverAuth: true, clientAuth: true, timeStamping: true }
      { name: 'subjectAltName', altNames: [
        { type: 2, value: irac }
        { type: 2, value: pki.pemCertificateToPemURL peer.cachain[0], 'irac_ca' }
        { type: 2, value: pki.pemCertificateToPemURL peer.cachain[1], 'irac_ia' }
      ] } ]
  console.log cert
  cert.sign @intermediate_key.privateKey, sha256.create()
  do $app.sync # save serial
  pki.certificateToPem cert

Peer.CA::signMessage = (message,key)->
  key = ( key || @key ).privateKey
  message.from = $config.hostid.irac
  message.date = Date.now()
  md = do sha256.create; md.update (JSON.stringify message), 'utf8'
  message.sign = (new Buffer key.sign(md),'binary').toString('base64')
  message

Peer.CA::verifyMessage = (message,key)->
  key = @key.publicKey if message.from is $config.hostid.irac
  unless key
    unless ( peer = PEER[message.from] ) and ( cert = peer.remote )
      peer = new Peer.Shadow irac:message.from
      ( peer.toVerify || peer.toVerify = [] ).push = message
      return false
    else key = pki.certificateFromPem(cert).publicKey
  sign = message.sign; delete message.sign
  md = do sha256.create; md.update (JSON.stringify message), 'utf8'
  message.sign = sign
  key.verify md.digest().bytes(), new Buffer sign, 'base64'

Peer.CA::setupFiles = ->
  $path.ca = (args...)-> $path.join.apply $path, [$path.configDir,'ca'].concat args
  $path.cadir = $path.ca()
  unless $fs.existsSync $path.cadir
    $fs.mkdirp.sync $path.cadir # ca directory

Peer.CA::setupCA = ->
  bits = 1024
  ca_extensions = [
    { name: 'basicConstraints', cA: true }
    { name: 'keyUsage', keyCertSign: true, digitalSignature: true, nonRepudiation: true, keyEncipherment: true, dataEncipherment: true }
    { name: 'extKeyUsage', serverAuth: true, clientAuth: true, codeSigning: true, emailProtection: true, timeStamping: true }
    { name: 'nsCertType', client: true, server: true, email: true, objsign: true, sslCA: true, emailCA: true, objCA: true }
    { name: 'subjectKeyIdentifier' } ]
  # CA KEY
  unless @caDisabled = $fs.existsSync $path.ca 'ca_outlet'
    unless $fs.existsSync path = $path.ca 'ca-key.pem'
      @cakey = rsa.generateKeyPair bits: bits, e: 0x10001
      $fs.writeFileSync path, pki.privateKeyToPem @cakey.privateKey
      console.log (' CA-KEY['+bits+'-bit/RSA] ').yellow.bold.inverse, $irac @cakey.publicKey
    else @cakey =
      privateKey: privateKey = pki.privateKeyFromPem $fs.readFileSync(path,'utf8')
      publicKey:  pki.setRsaPublicKey privateKey.n, privateKey.e
    # INTERMEDIATE_KEY
    unless $fs.existsSync path = $path.ca 'intermediate_ca-key.pem'
      @intermediate_key = rsa.generateKeyPair bits: bits, e: 0x10001
      $fs.writeFileSync path, pki.privateKeyToPem @intermediate_key.privateKey
      console.log (' IC-KEY['+bits+'-bit/RSA] ').yellow.bold.inverse, $irac @intermediate_key.publicKey
    else @intermediate_key =
      privateKey: privateKey = pki.privateKeyFromPem $fs.readFileSync(path,'utf8')
      publicKey:  pki.setRsaPublicKey privateKey.n, privateKey.e
    @ra = $irac @cakey.publicKey
  # CA CERTIFICATE
  unless $fs.existsSync path = $path.ca 'ca.pem'
    @ca = pki.createCertificate()
    @ca.publicKey = @cakey.publicKey
    # @ca.serialNumber = '0x' + ( ++$config.hostid.serial ).toString 16
    @ca.validity.notBefore = new Date
    @ca.validity.notAfter  = new Date
    @ca.validity.notAfter.setFullYear @ca.validity.notBefore.getFullYear() + 1
    @ca.setSubject @attrs '', @ra, '$ca'
    @ca.setIssuer  @attrs '', @ra, '$ca'
    @ca.setExtensions ca_extensions
    @ca.sign @cakey.privateKey, sha256.create()
    $fs.writeFileSync path, pki.certificateToPem @ca
  else @ca = pki.certificateFromPem $fs.readFileSync path, 'utf8'
  # INTERMEDIATE_CA
  unless $fs.existsSync path = $path.ca 'intermediate_ca.pem'
    crt = pki.createCertificate()
    crt.publicKey = @intermediate_key.publicKey
    crt.serialNumber = '0x' + ( ++$config.hostid.serial ).toString 16
    crt.validity.notBefore = new Date
    crt.validity.notAfter  = new Date
    crt.validity.notAfter.setFullYear crt.validity.notBefore.getFullYear() + 1
    crt.setIssuer  @attrs '', @ra, '$ca'
    crt.setSubject @attrs $irac(@intermediate_key.publicKey).substr(0,6), @ra, '$ca'
    crt.setExtensions ca_extensions
    crt.sign @cakey.privateKey, sha256.create()
    $fs.writeFileSync path, pki.certificateToPem @intermediate_ca = crt
  else @intermediate_ca = pki.certificateFromPem $fs.readFileSync path, 'utf8'
  @ia   = $irac @intermediate_ca.publicKey
  @ra = $irac @ca.publicKey
  null

Peer.CA::installKeys = ->
  # if $config.hostid.installed
  unless $fs.existsSync p = $path.join process.env.HOME, '.pki', 'nssdb'
    $fs.mkdirp.sync p
    $cp.spawnSync 'certutil',['-d',p,'-N']
  $cp.spawn 'certutil',
    ['-d','sql:' + process.env.HOME + '/.pki/nssdb','-A','-t','TCP','-n',$config.hostid.irac,'-i',$path.ca 'ca.pem']
  $cp.spawn 'pk12util',
    ['-d','sql:' + process.env.HOME + '/.pki/nssdb','-i',$path.ca('me.p12'),'-W','']
  #  $config.hostid.installed = true

Peer.CA::attrs = (prefix='',irac=@ra,ou='$ca',onion='irac')-> return [
  { shortName: 'CN', value: prefix + irac + '.irac' }
  { shortName: 'O',  value: onion }
  { shortName: 'OU', value: ou } ]

Peer.CA::rpw = (length)->
  r = forge.random.createInstance()
  r.seed = Date.now() + parseInt( $md5( JSON.stringify $config ), 16 )
  $B32 r.generate(length)
