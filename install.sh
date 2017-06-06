set -e
# install ntpd, replace timesyncd
sudo timedatectl set-ntp no
sudo apt-get -y install ntp

# install haveged
sudo apt-get -y install haveged
sudo update-rc.d haveged defaults

# download and install docker
sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
#sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
#sudo apt-get -y install docker-ce
#apt-cache madison docker-ce
sudo apt-get -y install docker-ce=17.03.1~ce-0~ubuntu-xenial

# pull image, configs and setup parity
sudo docker pull ethcore/parity:stable
curl -O 'https://raw.githubusercontent.com/oraclesorg/test-templates/master/demo-spec.json'
curl -O 'https://raw.githubusercontent.com/oraclesorg/test-templates/master/node.pwds'
curl -O 'https://raw.githubusercontent.com/oraclesorg/test-templates/master/node-to-enode.toml'
sed -i 's/@172.16./@/g' node-to-enode.toml
mkdir parity-data

# start parity in docker
sudo docker run -d \
    --name eth-parity \
    -p 30300:30300 \
    -p 8080:8080 \
    -p 8180:8180 \
    -p 8540:8540 \
    -v "$(pwd)/node.pwds:/build/node.pwds" \
    -v "$(pwd)/parity-data:/tmp/parity" \
    -v "$(pwd)/demo-spec.json:/build/demo-spec.json" \
    -v "$(pwd)/node-to-enode.toml:/build/node-to-enode.toml" \
    ethcore/parity:stable --config "node-to-enode.toml"
