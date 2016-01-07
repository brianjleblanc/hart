#!/bin/bash

tdir=`mktemp -d`
cd $tdir

/usr/bin/curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -
sudo /usr/bin/apt-get install -y nodejs git awscli nginx

DIR=/opt/node


if [[ ! -e $DIR ]]
then
  mkdir -p $DIR/log
  mkdir $DIR/pid
fi
cat << EOF  >> $DIR/app.js
var http = require('http');
http.createServer(function (req, res) {
  res.writeHead(200, {'Content-Type': 'text/plain'});
    res.end('Hello World!\n');
}).listen(3000, '0.0.0.0');
console.log('Server running at http://0.0.0.0:3000/');
EOF

/usr/bin/git clone http://github.com/chovy/node-startup
sed -i 's:/var/www/example\.com:/opt/node:' node-startup/init.d/node-app
mv node-startup/init.d/node-app /etc/init.d/
rm -rf $tdir
cd $DIR

sudo /etc/init.d/node-app start &> $DIR/start.log
sleep 2
started=`pgrep node`
if [[ -z $started ]]
then
    echo "Start failed, starting again"
    sudo /etc/init.d/node-app start &> $DIR/start.log
fi

cat << EOF  > /etc/nginx/conf.d/node.conf
server {
  listen       8080;
  server_name  localhost;

  location / {
    proxy_pass http://localhost:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_cache_bypass \$http_upgrade;
  }
}
EOF
cat << EOF  > /etc/nginx/sites-available/default
server {
       listen         80;
       return         301 https://bleblanc-nginx-530751056.us-west-2.elb.amazonaws.com;
}
EOF

sudo /etc/init.d/nginx restart


#mkdir /root/.aws

#cat << EOF > /root/.aws/config
#[default]
#region = us-west-2
#[profile elb]
#region = us-west-2
#role_arn = arn:aws:iam::417734741619:instance-profile/NodeJS
#source_profile = default
#EOF

#ELB="bleblanc-nginx"
#IID=`wget -q -O - http://instance-data/latest/meta-data/instance-id`

#Register
#aws --profile elb elb register-instances-with-load-balancer --load-balancer-name $ELB --instances $IID
