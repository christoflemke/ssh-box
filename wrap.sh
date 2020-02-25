#!/bin/bash

set -e
cd $(dirname $0)

if [ $# != 3 ]; then
    echo usage:
    echo $(basename $0) ssh-public-key-file secret-file out-file
    exit 1
fi

public_key_file=$(realpath $1)
secret_file=$(realpath $2)
touch $3
result="$(realpath $3)"
tmp_dir_name=/tmp/$(openssl rand -hex 32)

function finish {
  rm -rf $tmp_dir_name
}
trap finish EXIT

mkdir $tmp_dir_name
cd $tmp_dir_name

ssh-keygen -f $public_key_file -e -m PKCS8 > pub.pem
openssl rand -base64 32 > key.bin
openssl rsautl -encrypt -oaep -pubin -inkey pub.pem -in key.bin -out key.enc
openssl aes-256-cbc -in $secret_file -out secret.enc -pass file:key.bin

zipfile=data.zip

zip  $zipfile *



cat <<WRAPPER_START > wrapper_start.sh
#!/bin/bash

set -e

SSH_KEY=\${SSH_KEY:-\${HOME}/.ssh/id_rsa}
out=\$(pwd)/secret.txt
tmp_dir_name=/tmp/\$(openssl rand -hex 32)
function finish {
  rm -rf $tmp_dir_name
}
trap finish EXIT

mkdir $tmp_dir_name
cd $tmp_dir_name

cat <<EOF | base64 --decode > file.zip
WRAPPER_START

cat <<WRAPPER_END > wrapper_end.sh
EOF

unzip -q file.zip

openssl rsautl -decrypt -oaep -inkey \$SSH_KEY -in key.enc -out secret.key
openssl aes-256-cbc -d -in secret.enc -out \$out -pass file:secret.key
echo "secret written to \${out}"

WRAPPER_END

out_file=wraper.sh

cat wrapper_start.sh > $out_file
cat $zipfile | base64 >> $out_file
cat wrapper_end.sh >> $out_file

chmod u+x $out_file
mv $out_file $result


