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

{ tls, asn1, pkcs12, pki, md } = forge = $require 'node-forge'
{ md5, sha1, sha256, sha512 }   = md
{ rsa } = pki

pki.pemCertificateToPemURL = (cert,proto='irac') -> proto + '.' + cert.replace(/[\r\n]/g,'').replace(/-----[A-Z ]+-----/g,'')
pki.pemCertificateFromPemURL = (url) -> '-----BEGIN CERTIFICATE-----\r\n' + url.replace(/^[^.]+\./,'') + '\r\n-----END CERTIFICATE-----'
pki.certificateToPemURL = (cert,proto='irac') -> pki.pemCertificateToPemURL pki.certificateToPem(cert), proto
pki.certificateFromPemURL = (url) -> pki.certificateFromPem pki.pemCertificateFromPemURL url

$static
  $forge: forge
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
