DAYS="-days 365"
REQ="openssl req $SSLEAY_CONFIG"
CA="openssl ca $SSLEAY_CONFIG -config ca.cnf"
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

# Create new CA
# ------------------------------------------------------------------------------
dd if=/dev/urandom status=none bs=60 count=1 | openssl base64 -e -nopad | tr -d '\n' > cacertkey
echo '' >> cacertkey
mkdir ${CATOP}
mkdir ${CATOP}/certs
mkdir ${CATOP}/crl
mkdir ${CATOP}/newcerts
mkdir ${CATOP}/private
echo "01" > ${CATOP}/serial
touch ${CATOP}/index.txt

echo "== Making CA certificate ..."
sed "s/^\([[:space:]]*commonName_default\).*/\1 \t\t= Fake Org Fake CA - ${CASERIAL}/" template_ca.cnf > ca.cnf

$REQ -verbose -batch -passout file:cacertkey -new -x509 -keyout ${CATOP}/private/$CAKEY -out ${CATOP}/$CACERT $DAYS

echo "== Making Client certificates ..."
for hname in $*; do
  echo "-- $hname"
  mkdir -p "${keydist}/${hname}/cacerts"
  sed -e "s/#HOSTNAME#/$hname/" template_host.cnf > "working/${hname}.cnf"
  echo "-- running openssl req"
  $REQ -config "working/${hname}.cnf" -new -nodes -keyout ${keydist}/${hname}/${hname}.pem -out working/"${hname}"req.pem -days 360 -batch;
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
