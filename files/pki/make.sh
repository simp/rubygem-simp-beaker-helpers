# For ruby
export PATH=/opt/puppetlabs/puppet/bin:$PATH

DAYS="-days 365"
REQ="openssl req $SSLEAY_CONFIG"
CA="openssl ca $SSLEAY_CONFIG"
VERIFY="openssl verify"
X509="openssl x509"

CATOP=./demoCA
CAKEY=./cakey.pem
CACERT=./cacert.pem
CASERIAL=`uuidgen | cut -f1 -d'-'`

keydist=keydist

# start clean
bash clean.sh

mkdir -p working  "${keydist}" "${keydist}/cacerts"

# Create new CA if necessary
# ------------------------------------------------------------------------------
mkdir -p ${CATOP} ${CATOP}/certs ${CATOP}/crl ${CATOP}/newcerts ${CATOP}/private
if [ ! -f cacertkey ]; then
  dd if=/dev/urandom status=none bs=60 count=1 | openssl base64 -e -nopad | tr -d '\n' > cacertkey
  echo '' >> cacertkey
fi
if [ ! -f ${CATOP}/serial ]; then
  echo "01" > ${CATOP}/serial
fi
touch ${CATOP}/index.txt

echo "== Making CA certificate ..."
sed "s/^\([[:space:]]*commonName_default\).*/\1 \t\t= Fake Org Fake CA - ${CASERIAL}/" template_ca.cnf > ca.cnf

export OPENSSL_CONF=ca.cnf

$REQ -verbose -batch -passout file:cacertkey -new -x509 -keyout ${CATOP}/private/$CAKEY -out ${CATOP}/$CACERT $DAYS

echo "== Making Client certificates ..."
for hosts in $*; do
  hosts=`echo $hosts | sed -e 's/[ \t]//g'`
  hname=`echo $hosts | cut -d',' -f1`

  echo "-- $hname"
  mkdir -p "${keydist}/${hname}/cacerts"

  sed -e "s/#HOSTNAME#/${hname}/" template_host.cnf > "working/${hname}.cnf"

  if [ "$hname" != "$hosts" ];
  then
    alts=`echo $hosts | cut -d',' -f1-`
    altnames=''
    for i in `echo $alts | tr ',' '\n'`
    do
      ruby -r ipaddr -e "begin IPAddr.new('$i') rescue exit 1 end"
      if [ $? -eq 0 ]; then
        # This is required due to some applications not properly supporting the
        # IP version of subjectAltName.
        prefixes='IP DNS'
      else
        prefixes='DNS'
      fi

      for prefix in $prefixes; do
        if [ "$altnames" != ''  ]
        then
          altnames+=",$prefix:$i"
        else
          altnames+="$prefix:$i"
        fi
      done
    done

    sed -i "s/# subjectAltName = #ALTNAMES#/subjectAltName = ${altnames}/" "working/${hname}.cnf"
  fi

  echo "-- running openssl req"

  export OPENSSL_CONF="working/${hname}.cnf"

  $REQ -new -nodes -keyout ${keydist}/${hname}/${hname}.pem -out working/"${hname}"req.pem -days 360 -batch;

  echo "-- running openssl ca"

  $CA -passin file:cacertkey -batch -out ${keydist}/${hname}/${hname}.pub -infiles working/"${hname}"req.pem

  cat ${keydist}/${hname}/${hname}.pub >> ${keydist}/${hname}/${hname}.pem
done

echo "== Hashing CA certs"
cacerts="${keydist}/cacerts"
hash=`openssl x509 -in ${CATOP}/${CACERT} -hash -noout`;
cp ${CATOP}/${CACERT} $cacerts/cacert_${CASERIAL}.pem
cd $cacerts
ln -s cacert_${CASERIAL}.pem $hash.0
cd -

chmod -R u+rwX,g+rX,o-rwx $keydist
#chown -R root:puppet $keydist
