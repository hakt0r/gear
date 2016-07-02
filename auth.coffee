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
  @npm 'node-forge'
  @mod 'crypto', 'peer'
  @apt certutil: 'libnss3-tools'
  @defer()

setImmediate ->
  new Auth
  do $require.Module.byName.auth.resolve

$app.on 'daemon', ->
  console.log Peer.format($auth), '  I R A C  '.log, ( unless $auth.caDisabled then ' $ca ' else ' $host ' ).ok
  for i,p of $config.peers when i isnt $auth.irac
    delete $config.peers[i]
    new Peer.Remote p
  null

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

class Auth extends Peer
  constructor:->
    global.$auth = Object.assign @, $config.host || {}
    @serial = @serial || @serial = 0
    @group  =  ['$local']
    do @setupFiles
    do @setupCA
    @cachain = [
      $pki.certificateToPem @ca
      $pki.certificateToPem @intermediate_ca ]
    Object.assign @, do @setupKeys
    PEER[@irac] = @
    do @installKeys
    do @register
    Object.freeze(@group)

Object.defineProperty Auth::, 'auth', get:->
  ra:@ra,ia:@ia,irac:@irac,onion:@onion,remote:@remote,cert:@cert,cachain:@cachain,group:@group

Auth::newSerial = -> @serial++
Auth::formatSerial = -> @newSerial().toString 16

Auth::setupKeys = (host='me')-> # onion / server / client key - package
  exports = {}
  unless $fs.existsSync path = $path.ca host+'_onion.pem'
    o = do $onion
    $fs.writeFileSync path, o.pem
    $fs.writeFileSync $path.ca(host+'_onion.pub'), o.pem_public
  else o = $onion $fs.readFileSync $path.ca(host+'_onion.pub'), 'utf8'
  exports.onion = o.onion
  unless $fs.existsSync path = $path.ca host+'.pem'
    exports.key = $rsa.generateKeyPair bits: 1024, e: 0x10001
    $fs.writeFileSync path, $pki.privateKeyToPem exports.key.privateKey
    console.log ' HOST '.ok, host, $irac exports.key.publicKey
  else exports.key =
    privateKey: privateKey = $pki.privateKeyFromPem $fs.readFileSync(path,'utf8')
    publicKey:  publicKey  = $pki.setRsaPublicKey privateKey.n, privateKey.e
    modulus: publicKey.n.toString(16).toUpperCase()
  unless $fs.existsSync path = $path.ca host+'.crt' # certificate / pem
    exports.irac = $irac exports.key.publicKey
    cert = $pki.createCertificate()
    cert.signatureOid = $pki.oids['rsaEncryption']
    cert.publicKey    = exports.key.publicKey
    cert.serialNumber = do @formatSerial
    cert.validity.notBefore = new Date
    cert.validity.notAfter  = new Date
    cert.validity.notAfter.setFullYear cert.validity.notBefore.getFullYear() + 1
    cert.setIssuer @intermediate_ca.subject.attributes
    cert.setSubject @attrs exports.irac, (if host is 'me' then '$local' else '$host'), exports.onion
    cert.setExtensions [
      { name: 'extKeyUsage', serverAuth:  true, clientAuth: true, timeStamping: true }
      { name: 'subjectAltName', altNames: [
        { type: 2, value: exports.irac + '.irac' }
        { type: 2, value: exports.irac }
        { type: 2, value: exports.onion }
        { type: 2, value: 'irac' }
        { type: 2, value: 'localhost' }
        { type: 2, value: $pki.certificateToPemURL @ca, 'irac_ca' }
        { type: 2, value: $pki.certificateToPemURL @intermediate_ca, 'irac_ia' }
        { type: 7, ip: '127.0.0.1' } ] } ]
    cert.sign @intermediate_key.privateKey, $forge.md.sha256.create()
    $fs.writeFileSync path, exports.cert = $pki.certificateToPem cert
  else exports.cert = $fs.readFileSync path, 'utf8'
  unless $fs.existsSync path = $path.ca(host+'.p12') # certificate / pkcs12 - for browsers
    p12 = $forge.pkcs12.toPkcs12Asn1 exports.key.privateKey, [exports.cert,@ca], '', algorithm:'3des'
    $fs.writeFileSync path, new Buffer $forge.asn1.toDer(p12).getBytes(), 'binary'
  exports.irac = $irac exports.key.publicKey
  exports.ia = @ia
  exports.ra = @ra
  exports.pem = $pki.privateKeyToPem exports.key.privateKey
  exports

Auth::createHost = (hostname,address)->
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

Auth::authorize = (peer, group='$peer')->
  return false if @caDisabled
  { irac, ia, root, onion, remote } = peer
  cert = $pki.createCertificate()
  cert.publicKey = $pki.certificateFromPem(remote).publicKey
  cert.serialNumber = do @formatSerial
  cert.validity.notBefore = new Date
  cert.validity.notAfter  = new Date
  cert.validity.notAfter.setFullYear cert.validity.notBefore.getFullYear() + 1
  cert.setSubject @attrs irac, group, peer.onion
  cert.setIssuer @intermediate_ca.subject.attributes
  cert.setExtensions [
      { name: 'keyUsage', keyCertSign: no, digitalSignature: true, nonRepudiation: true, keyEncipherment: true, dataEncipherment: true }
      { name: 'extKeyUsage', serverAuth: true, clientAuth: true, timeStamping: true }
      { name: 'subjectAltName', altNames: [
        { type: 2, value: irac }
        { type: 2, value: $pki.pemCertificateToPemURL peer.cachain[0], 'irac_ca' }
        { type: 2, value: $pki.pemCertificateToPemURL peer.cachain[1], 'irac_ia' }
      ] } ]
  cert.sign @intermediate_key.privateKey, $forge.md.sha256.create()
  do $app.sync # save serial
  $pki.certificateToPem cert

Auth::signMessage = (message,key)->
  key = ( key || @key ).privateKey
  message.irac = $auth.irac unless message.irac
  message.date = Date.now()          unless message.date
  md = $forge.md.sha256.create().update (JSON.stringify message), 'utf8'
  message.sign = (new Buffer key.sign(md),'binary').toString('base64')
  message

Auth::verifyMessage = (message,key)->
  key = @key.publicKey if message.irac is $auth.irac
  unless key
    unless ( peer = PEER[message.irac] ) and ( cert = peer.remote )
      peer = new Peer.Shadow irac:message.irac
      ( peer.toVerify || peer.toVerify = [] ).push = message
      return false
    else key = $pki.certificateFromPem(cert).publicKey
  sign = message.sign; delete message.sign
  md = do $forge.md.sha256.create; md.update (JSON.stringify message), 'utf8'
  message.sign = sign
  key.verify md.digest().bytes(), new Buffer sign, 'base64'

Auth::setupFiles = ->
  $path.ca = (args...)-> $path.join.apply $path, [$path.configDir,'ca'].concat args
  $path.cadir = $path.ca()
  unless $fs.existsSync $path.cadir
    $fs.mkdirp.sync $path.cadir # ca directory

Auth::setupCA = ->
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
      @cakey = $rsa.generateKeyPair bits: bits, e: 0x10001
      $fs.writeFileSync path, $pki.privateKeyToPem @cakey.privateKey
      console.log (' CA-KEY['+bits+'-bit/RSA] ').warn, $irac @cakey.publicKey
    else @cakey =
      privateKey: privateKey = $pki.privateKeyFromPem $fs.readFileSync(path,'utf8')
      publicKey:  $pki.setRsaPublicKey privateKey.n, privateKey.e
    # INTERMEDIATE_KEY
    unless $fs.existsSync path = $path.ca 'intermediate_ca-key.pem'
      @intermediate_key = $rsa.generateKeyPair bits: bits, e: 0x10001
      $fs.writeFileSync path, $pki.privateKeyToPem @intermediate_key.privateKey
      console.log (' IC-KEY['+bits+'-bit/RSA] ').warn, $irac @intermediate_key.publicKey
    else @intermediate_key =
      privateKey: privateKey = $pki.privateKeyFromPem $fs.readFileSync(path,'utf8')
      publicKey:  $pki.setRsaPublicKey privateKey.n, privateKey.e
    @ra = $irac @cakey.publicKey
  # CA CERTIFICATE
  unless $fs.existsSync path = $path.ca 'ca.pem'
    @ca = $pki.createCertificate()
    @ca.publicKey = @cakey.publicKey
    @ca.serialNumber = do @formatSerial
    @ca.validity.notBefore = new Date
    @ca.validity.notAfter  = new Date
    @ca.validity.notAfter.setFullYear @ca.validity.notBefore.getFullYear() + 1
    @ca.setSubject @attrs @ra, '$ra'
    @ca.setIssuer  @attrs @ra, '$ra'
    @ca.setExtensions ca_extensions
    @ca.sign @cakey.privateKey, $forge.md.sha256.create()
    $fs.writeFileSync path, $pki.certificateToPem @ca
  else @ca = $pki.certificateFromPem $fs.readFileSync path, 'utf8'
  # INTERMEDIATE_CA
  unless $fs.existsSync path = $path.ca 'intermediate_ca.pem'
    ia = $irac @intermediate_key.publicKey
    crt = $pki.createCertificate()
    crt.publicKey = @intermediate_key.publicKey
    crt.serialNumber = do @formatSerial
    crt.validity.notBefore = new Date
    crt.validity.notAfter  = new Date
    crt.validity.notAfter.setFullYear crt.validity.notBefore.getFullYear() + 1
    crt.setIssuer  @attrs @ra,'$ra'
    crt.setSubject @attrs ia, '$ia'
    crt.setExtensions ca_extensions
    crt.sign @cakey.privateKey, $forge.md.sha256.create()
    $fs.writeFileSync path, $pki.certificateToPem @intermediate_ca = crt
  else @intermediate_ca = $pki.certificateFromPem $fs.readFileSync path, 'utf8'
  @ia = $irac @intermediate_ca.publicKey
  @ra = $irac @ca.publicKey
  null

Auth::installKeys = ->
  # if $auth.installed
  unless $fs.existsSync p = $path.join process.env.HOME, '.pki', 'nssdb'
    $fs.mkdirp.sync p
    $cp.spawnSync 'certutil',['-d',p,'-N']
  $cp.spawn 'certutil',
    ['-d','sql:' + process.env.HOME + '/.pki/nssdb','-A','-t','TCP','-n',$auth.irac,'-i',$path.ca 'ca.pem']
  $cp.spawn 'pk12util',
    ['-d','sql:' + process.env.HOME + '/.pki/nssdb','-i',$path.ca('me.p12'),'-W','']
  #  $auth.installed = true

Auth::attrs = (irac=@ra,ou='$ra',onion='$irac')-> return [
  { shortName: 'CN', value: irac + '.irac' }
  { shortName: 'O',  value: onion }
  { shortName: 'OU', value: ou } ]

Auth::rpw = (length)->
  r = $forge.random.createInstance()
  r.seed = Date.now() + parseInt( $md5( JSON.stringify $config ), 16 )
  $B32 r.generate(length)
