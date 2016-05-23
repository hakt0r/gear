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

  [ Recommended soundtrack for patching: ]

       Flux Pavilion - I Can't Stop
      Camo & Krooked - Nothing is older than yesterday
              John B - Numbers (Camo & Krooked Remix)
              Netsky - We Can Only Live Today (Puppy) (Feat Billie) - Camo & Krooked Remix
           B-Complex - Beautiful Lies VIP
         Freestylers - Cracks (Ft. Belle Humble) (Flux Pavilion Remix)
      Maduk ft Veela - Ghost Assassin
                SAIL - AWOLNATION
               Adele - Hometown Glory (High Contrast Remix)
        The Agitator - Say No (Cutline Remix)

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

$static $auth: new class Auth
  constructor: (ready) ->
    $config.hostid = $config.hostid || {}
    @serial = $config.hostid.serial || 0

    do @setupFiles
    do @setupCA
    do @setupKeys
    do @installKeys

    @local = $config.hostid = Object.assign $config.hostid,
      key:     pki.privateKeyToPem @key.privateKey
      ca:      ca_intr = pki.certificateToPem @intermediate_ca
      caroot:  ca_root = pki.certificateToPem @ca
      cachain: [ca_root,ca_intr]
      cert:    @cert
      irac:    @irac
      serial:  @serial

    do $require.Module.byName.auth.resolve

  verify: (target,socket,inbound)->
    cert = socket.getPeerCertificate true
    unless cert and cert.modulus
      console.log ' CONNECTION WITHOUT CERTIFICATE '.red.inverse, ' WILL NOT BE TOLERATED '.red.inverse.bold
      return false
    if ( s = cert.subject.CN ) and ( ( s = s.toString() ).match /\.irac$/ )
      irac = s.replace(/.irac$/,'').replace(/.*\./,'')
    else try irac = cert.subjectaltname.split(', ').filter( (i) -> i.match /[a-z0-9]{52}/ )[0].replace /DNS:/, ''
    unless irac and irac.match /^[a-z0-9]{52}$/
      console.log ' CONNECTION WITHOUT IRAC-CERTIFICATE '.red.inverse, ' WILL NOT BE TOLERATED '.red.inverse.bold
      console.log ' SUBJECT '.red.inverse, cert.subject
      return false
    dir = if inbound then 'inbound' else 'outbound'
    realSocket = socket.outSocket || socket
    if true is ( cert.authorized = realSocket.authorized ) and ( irac is @irac or PEER[irac]? )
      target.irac = cert.irac = irac
      socket.getPeerCertificate = -> cert
      group = if ( irac is @irac ) then ['$local'] else PEER[irac].group
      group = group.concat ['$public','$peer','$buddy'] unless -1 is group.indexOf '$local'
      group = group.concat ['$public','$peer']          unless -1 is group.indexOf '$buddy'
      group = group.concat ['$public']                  unless -1 is group.indexOf '$peer'
      group = Array.unique group
      console.log " AUTH(#{dir}) ".green.inverse, cert.subject.CN, group
    else
      console.error " AUTH(#{dir}) ".red.inverse, cert.subject.CN, ( socket.outSocket || socket ).authorizationError
      group = ['$public']
    target.group = socket.group = cert.group = group
    target.cert = socket.cert = cert
    cert

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
    unless $fs.existsSync path = $path.ca 'ca-key.pem'
      @cakey = rsa.generateKeyPair bits: bits, e: 0x10001
      $fs.writeFileSync path, pki.privateKeyToPem @cakey.privateKey
      console.log 'CA - Generated '+bits+' bit RSA Private Key - ' + pki.getPublicKeyFingerprint(@cakey.publicKey,md:sha256.create(),encoding:'hex',delimiter:':')
    else @cakey =
      privateKey: privateKey = pki.privateKeyFromPem $fs.readFileSync(path,'utf8')
      publicKey:  pki.setRsaPublicKey privateKey.n, privateKey.e
    @irac = $irac @cakey.publicKey
    console.log 'irac[' + @irac + ']'
    # CA CERTIFICATE
    unless $fs.existsSync path = $path.ca 'ca.pem'
      @ca = pki.createCertificate()
      @ca.publicKey = @cakey.publicKey
      # @ca.serialNumber = '0x' + ( ++@serial ).toString 16
      @ca.validity.notBefore = new Date
      @ca.validity.notAfter  = new Date
      @ca.validity.notAfter.setFullYear @ca.validity.notBefore.getFullYear() + 1
      @ca.setSubject @attrs 'master.', @irac, '$ca'
      @ca.setIssuer  @attrs 'master.', @irac, '$ca'
      @ca.setExtensions ca_extensions
      @ca.sign @cakey.privateKey, sha256.create()
      $fs.writeFileSync path, pki.certificateToPem @ca
    else @ca = pki.certificateFromPem $fs.readFileSync path, 'utf8'
    # INTERMEDIATE_KEY
    unless $fs.existsSync path = $path.ca 'intermediate_ca-key.pem'
      @intermediate_key = rsa.generateKeyPair bits: bits, e: 0x10001
      $fs.writeFileSync path, pki.privateKeyToPem @intermediate_key.privateKey
      console.log 'CA-INTERMEDIATE - Generated '+bits+' bit RSA Private Key - ' + pki.getPublicKeyFingerprint(@intermediate_key.publicKey,md:sha256.create(),encoding:'hex',delimiter:':')
    else @intermediate_key =
      privateKey: privateKey = pki.privateKeyFromPem $fs.readFileSync(path,'utf8')
      publicKey:  pki.setRsaPublicKey privateKey.n, privateKey.e
    # INTERMEDIATE_CA
    unless $fs.existsSync path = $path.ca 'intermediate_ca.pem'
      crt = pki.createCertificate()
      crt.publicKey = @intermediate_key.publicKey
      crt.serialNumber = '0x' + ( ++@serial ).toString 16
      crt.validity.notBefore = new Date
      crt.validity.notAfter  = new Date
      crt.validity.notAfter.setFullYear crt.validity.notBefore.getFullYear() + 1
      crt.setIssuer  @attrs 'master.', @irac, '$ca'
      crt.setSubject @attrs 'i0.', @irac, '$ca'
      crt.setExtensions ca_extensions
      crt.sign @cakey.privateKey, sha256.create()
      $fs.writeFileSync path, pki.certificateToPem @intermediate_ca = crt
    else @intermediate_ca = pki.certificateFromPem $fs.readFileSync path, 'utf8'
    null

  setupKeys:->
    # server / client key
    unless $fs.existsSync path = $path.ca 'me.pem'
      @key = rsa.generateKeyPair bits: 1024, e: 0x10001
      $fs.writeFileSync path, pki.privateKeyToPem @key.privateKey
      console.log 'Generated Host Key: ' + $B32(new Buffer pki.getPublicKeyFingerprint(@key.publicKey, md:sha256.create()).data,'binary')
    else @key =
      privateKey: privateKey = pki.privateKeyFromPem $fs.readFileSync(path,'utf8')
      publicKey:  publicKey = pki.setRsaPublicKey privateKey.n, privateKey.e
      modulus: publicKey.n.toString(16).toUpperCase()
    # server / client certificate / pem
    unless $fs.existsSync path = $path.ca 'me.crt'
      cert = pki.createCertificate()
      cert.signatureOid = pki.oids['rsaEncryption']
      cert.publicKey    = @key.publicKey
      cert.serialNumber = '0x' + ( ++@serial ).toString 16
      cert.validity.notBefore = new Date
      cert.validity.notAfter  = new Date
      cert.validity.notAfter.setFullYear cert.validity.notBefore.getFullYear() + 1
      cert.setIssuer @attrs 'i0.', @irac, '$ca'
      cert.setSubject @attrs 's0.', @irac, '$local'
      cert.setExtensions [
        { name: 'extKeyUsage', serverAuth:  true, clientAuth: true, timeStamping: true }
        { name: 'subjectAltName', altNames: [
          { type: 2, value: @irac }
          { type: 2, value: 'irac' }
          { type: 2, value: 'localhost' }
          { type: 7, ip: '127.0.0.1' }
          { type: 7, ip: '127.0.1.1' }
      ] } ]
      cert.sign @intermediate_key.privateKey, sha256.create()
      $fs.writeFileSync path, @cert = pki.certificateToPem cert
    else @cert = $fs.readFileSync path, 'utf8'
    # server / client certificate / pkcs12 - for browsers
    unless $fs.existsSync path = $path.ca('me.p12')
      p12 = pkcs12.toPkcs12Asn1 @key.privateKey, [@cert,@ca], '', algorithm:'3des'
      $fs.writeFileSync path, new Buffer asn1.toDer(p12).getBytes(), 'binary'

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

  attrs: (prefix='',irac=@irac,ou='$ca')-> return [
    { shortName: 'CN', value: prefix + irac + '.irac' }
    { shortName: 'O',  value: 'irac' }
    { shortName: 'OU', value: ou } ]

  request:(subject='')->
    subject += '.' if subject isnt ''
    csr = pki.createCertificationRequest()
    csr.signatureOid = pki.oids['rsaEncryption']
    csr.publicKey = @key.publicKey
    csr.setSubject @attrs subject
    csr.sign @key.privateKey, sha256.create()
    pki.certificationRequestToPem csr

  authorize: (csr)->
    csr = pki.certificationRequestFromPem csr if typeof csr is 'string'
    irac = csr.subject.attributes.filter( (i)-> i.shortName ).shift().value.replace(/\.irac$/,'').replace(/.*\./,'')
    cert = pki.createCertificate()
    cert.publicKey = csr.publicKey
    cert.serialNumber = '0x' + ( ++@serial ).toString 16
    cert.validity.notBefore = new Date
    cert.validity.notAfter  = new Date
    cert.validity.notAfter.setFullYear cert.validity.notBefore.getFullYear() + 1
    cert.setSubject @attrs '', irac, '$peer'
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
      return 'ENOPEER' unless ( peer = PEER[message.from] ) and ( cert = peer.remote )
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
