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

{ tls, asn1, pkcs12, pki, md } = forge = $require 'node-forge'
{ md5, sha1, sha256, sha512 }   = md
{ rsa } = pki

cipherSuites = [
  tls.CipherSuites.TLS_RSA_WITH_AES_128_CBC_SHA
  tls.CipherSuites.TLS_RSA_WITH_AES_256_CBC_SHA ]

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

$config.peers = $config.peers || {}

$static class Peer
  constructor:(auth,settings)->
    return false if false is auth
    return false unless auth.irac
    if (peer = PEER[auth.irac])? and peer.update
      return peer.update(auth,settings)
    else @update auth, settings
    Peer.byIRAC[@irac] = @
    Peer.pushCA @root, @ if @root
    console.log Peer.format(@), ' PEER '.blue.bold.inverse
  parseCertificate:(cert=@pem,ca)->
    Object.assign @, $auth.parseCertificate cert, ca
    @cachain = ca if ca
    Peer.pushCA @root, @ if @root
    do $app.sync
    console.log Peer.format(@), ' PEER-UPGRADE '.blue.bold.inverse
  update:(auth,settings)->
    Object.assign @, settings, auth
    do @groups
    do $app.sync
  groups:(args...)->
    @group = @group || ['$public']
    @group = @group.concat args
    @group = @group.concat ['$public','$peer','$buddy','$host'] unless -1 is @group.indexOf '$local'
    @group = @group.concat ['$public','$peer','$buddy']         unless -1 is @group.indexOf '$host'
    @group = @group.concat ['$public','$peer']                  unless -1 is @group.indexOf '$buddy'
    @group = @group.concat ['$public']                          unless -1 is @group.indexOf '$peer'
    @group = Array.unique @group

$static PEER: Peer.byIRAC = $config.peers

Peer.byCA = {}

Peer.format = (peer)->
  o = []
  o.push peer.name.substr(0,6).green.bold if peer.name
  o.push peer.root.substr(0,6).green.bold if peer.root
  o.push peer.ia.substr(0,2).blue.bold if peer.ia
  o.push peer.irac.substr(0,6).yellow.bold if peer.irac
  o.push peer.onion.white.bold if peer.onion
  o = o.join '.'
  if peer.address
    o + '[' + ( if peer.address is peer.irac then DIRECT[peer.address] || "n/a" else peer.address ).yellow.bold + ']'
  else o

Peer.pushCA = (root,peer)->
  l = Peer.byCA[root] = Peer.byCA[root] || list:[]
  l.list.push l[peer.irac] = peer
  l

new class Auth
  constructor: (ready) ->
    $static $auth: @
    $config.hostid = $config.hostid || {}
    $config.hostid.serial = $config.hostid.serial || 0

    do @setupFiles
    do @setupCA
    keys = do @setupKeys
    do @installKeys
    Object.assign @, keys
    ca_intr = pki.certificateToPem @intermediate_ca
    ca_root = pki.certificateToPem @ca
    cachain = [ca_root, ca_intr]
    Object.assign $config.hostid,
      ca:      ca_intr
      cachain: [ca_root,ca_intr]
      group:   ['$local']
      direct:  yes
      myself:  yes
    $config.hostid = new Peer keys, $config.hostid
    console.log ' IRAC '.blue.bold.inverse, Peer.format($config.hostid)

    for i,p of $config.peers when i isnt @irac
      # console.log p
      p = new Peer {}, p

    do $require.Module.byName.auth.resolve

  parseCertificate: (cert,ca)->
    return false unless cert
    try
      sa_crt = (
        if typeof cert is 'string' then pki.certificateFromPem cert
        else if cert.raw then           pki.certificateFromAsn1 asn1.fromDer forge.util.createBuffer cert.raw, 'raw' )
      if cert.issuerCertificate
        ia_crt  = pki.certificateFromAsn1 asn1.fromDer forge.util.createBuffer cert.issuerCertificate.raw, 'raw'
        ca_crt  = pki.certificateFromAsn1 asn1.fromDer forge.util.createBuffer cert.issuerCertificate.issuerCertificate.raw, 'raw'
      else if ca then [ ca_crt, ia_crt ] = ca.map(pki.certificateFromPem)
      sa_irac = $irac sa_crt.publicKey
      if ia_crt and ca_crt
        ia_irac = $irac ia_crt.publicKey
        ca_irac = $irac ca_crt.publicKey
      return {
        remote:  pki.certificateToPem sa_crt
        remotepub: pki.publicKeyToPem sa_crt.publicKey
        irac:sa_irac
        ia:ia_irac
        root:ca_irac
        onion:sa_crt.subject.getField('O').value }
    catch exception then console.error ' PARSE-CERTIFICATE '.red.bold.inverse, cert, exception.stack || exception
    return false

  verify: (target,socket,inbound)->
    unless ( cert = socket.getPeerCertificate true )?
      console.log ' CONNECTION WITHOUT CERTIFICATE '.red.inverse, ' WILL NOT BE TOLERATED '.red.inverse.bold
      return false
    if false is ( opts = $auth.parseCertificate cert )
      console.log ' CONNECTION WITHOUT IRAC-CERTIFICATE '.red.inverse, ' WILL NOT BE TOLERATED '.red.inverse.bold
      console.log ' SUBJECT '.red.inverse, cert.subject
      return false
    { irac, root, host, ia } = opts
    dir = if inbound then 'inbound' else 'outbound'
    realSocket = socket.outSocket || socket
    if true is ( cert.authorized = realSocket.authorized )
      if inbound and not PEER[irac]
        console.log ' AUTO-PEER '.red.bold.inverse, irac
        peer = new Peer opts, group:[cert.subject.OU.toString().replace /\$local/,'$host']
      if peer or peer = PEER[irac]
        target.irac = cert.irac = irac
        socket.getPeerCertificate = -> cert
        console.log " PEER-AUTH(#{dir}) ".green.inverse, Peer.format(peer)
        console.debug peer.group.join('/'), Object.keys(peer).join('/')
        return target.peer = socket.peer = peer
    console.error " PUBLIC(#{dir}) ".red.inverse, cert.subject.CN, ( socket.outSocket || socket ).authorizationError
    console.error " PUBLIC(#{dir}) ".red.inverse, host, ia, root, cert.subject
    target.peer = socket.peer = new Peer opts, group:['$public']

  setupFiles:->
    $path.ca = (args...)-> $path.join.apply $path, [$path.configDir,'ca'].concat args
    $path.cadir = $path.ca()
    unless $fs.existsSync $path.cadir
      $fs.mkdirp.sync $path.cadir # ca directory

  setupCA:->
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
      @root = $irac @cakey.publicKey
    # CA CERTIFICATE
    unless $fs.existsSync path = $path.ca 'ca.pem'
      @ca = pki.createCertificate()
      @ca.publicKey = @cakey.publicKey
      # @ca.serialNumber = '0x' + ( ++$config.hostid.serial ).toString 16
      @ca.validity.notBefore = new Date
      @ca.validity.notAfter  = new Date
      @ca.validity.notAfter.setFullYear @ca.validity.notBefore.getFullYear() + 1
      @ca.setSubject @attrs '', @root, '$ca'
      @ca.setIssuer  @attrs '', @root, '$ca'
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
      crt.setIssuer  @attrs '', @root, '$ca'
      crt.setSubject @attrs $irac(@intermediate_key.publicKey).substr(0,6), @root, '$ca'
      crt.setExtensions ca_extensions
      crt.sign @cakey.privateKey, sha256.create()
      $fs.writeFileSync path, pki.certificateToPem @intermediate_ca = crt
    else @intermediate_ca = pki.certificateFromPem $fs.readFileSync path, 'utf8'
    @ia   = $irac @intermediate_ca.publicKey
    @root = $irac @ca.publicKey
    null

  setupKeys:(host='me')-> # onion / server / client key - package
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
      cert.setSubject @attrs exports.irac.substr(0,6) + '.', @root, (if host is 'me' then '$local' else '$host'), exports.onion
      cert.setExtensions [
        { name: 'extKeyUsage', serverAuth:  true, clientAuth: true, timeStamping: true }
        { name: 'subjectAltName', altNames: [
          { type: 2, value: exports.irac.substr(0,6) + '.' + @root + '.irac' }
          { type: 2, value: exports.irac }
          { type: 2, value: exports.onion }
          { type: 2, value: 'irac' }
          { type: 2, value: 'localhost' }
          { type: 7, ip: '127.0.0.1' } ] } ]
      cert.sign @intermediate_key.privateKey, sha256.create()
      $fs.writeFileSync path, exports.cert = pki.certificateToPem cert
    else exports.cert = $fs.readFileSync path, 'utf8'
    unless $fs.existsSync path = $path.ca(host+'.p12') # certificate / pkcs12 - for browsers
      p12 = pkcs12.toPkcs12Asn1 exports.key.privateKey, [exports.cert,@ca], '', algorithm:'3des'
      $fs.writeFileSync path, new Buffer asn1.toDer(p12).getBytes(), 'binary'
    exports.irac = $irac exports.key.publicKey
    exports.ia = @ia
    exports.root = @root
    exports.pem = pki.privateKeyToPem exports.key.privateKey
    exports

  installKeys:->
    # if $config.hostid.installed
    unless $fs.existsSync p = $path.join process.env.HOME, '.pki', 'nssdb'
      $fs.mkdirp.sync p
      $cp.spawnSync 'certutil',['-d',p,'-N']
    $cp.spawn 'certutil',
      ['-d','sql:' + process.env.HOME + '/.pki/nssdb','-A','-t','TCP','-n',$config.hostid.irac,'-i',$path.ca 'ca.pem'],
      stdio: 'inherit'
    $cp.spawn 'pk12util',
      ['-d','sql:' + process.env.HOME + '/.pki/nssdb','-i',$path.ca('me.p12'),'-W',''],
      stdio: 'inherit'
    #  $config.hostid.installed = true

  attrs: (prefix='',irac=@root,ou='$ca',onion='irac')-> return [
    { shortName: 'CN', value: prefix + irac + '.irac' }
    { shortName: 'O',  value: onion }
    { shortName: 'OU', value: ou } ]

  authorize: (peer, group='$peer')->
    return false if @caDisabled
    { irac, ia, root, onion, pub } = peer
    console.log peer.pub
    cert = pki.createCertificate()
    cert.publicKey = pki.publicKeyFromPem pub
    cert.serialNumber = '0x' + ( ++$config.hostid.serial ).toString 16
    cert.validity.notBefore = new Date
    cert.validity.notAfter  = new Date
    cert.validity.notAfter.setFullYear cert.validity.notBefore.getFullYear() + 1
    cert.setSubject @attrs '', irac, group
    cert.setIssuer @intermediate_ca.subject.attributes
    cert.setExtensions [
        { name: 'keyUsage', keyCertSign: no, digitalSignature: true, nonRepudiation: true, keyEncipherment: true, dataEncipherment: true }
        { name: 'extKeyUsage', serverAuth: true, clientAuth: true, timeStamping: true }
        { name: 'subjectAltName', altNames: [ { type: 2, value: irac } ] } ]
    cert.sign @intermediate_key.privateKey, sha256.create()
    do $app.sync # save serial
    pki.certificateToPem cert

  signMessage:(message,key)->
    key = ( key || @key ).privateKey
    message.from = $config.hostid.irac
    message.date = Date.now()
    md = do sha256.create; md.update (JSON.stringify message), 'utf8'
    message.sign = (new Buffer key.sign(md),'binary').toString('base64')
    message

  verifyMessage:(message,key)->
    if message.from is $config.hostid.irac
      key = @key.publicKey
    unless key
      unless ( peer = PEER[message.from] ) and ( cert = peer.remote )
        console.log 'ENOPEER', Object.keys peer
        return 'ENOPEER'
      console.log 'PEER-EXISTS', message, peer
      key = pki.certificateFromPem(cert).publicKey
    return 'ENOKEY' unless key
    sign = message.sign; delete message.sign
    md = do sha256.create; md.update (JSON.stringify message), 'utf8'
    message.sign = sign
    key.verify md.digest().bytes(), new Buffer sign, 'base64'

  rpw:(length)->
    r = forge.random.createInstance()
    r.seed = Date.now() + parseInt( $md5( JSON.stringify $config ), 16 )
    $B32 r.generate(length)
