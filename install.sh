sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
#sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
#sudo apt-get install docker-ce
#apt-cache madison docker-ce
sudo apt-get install docker-ce=17.03.1~ce-0~ubuntu-xenial
sudo docker pull ethcore/parity:stable
sudo docker
curl -O https://raw.githubusercontent.com/oraclesorg/test-templates/master/demo-spec.json
curl -O https://raw.githubusercontent.com/oraclesorg/test-templates/master/node-to-enode.json
curl -O https://raw.githubusercontent.com/oraclesorg/test-templates/master/node.pwds
mkdir parity-data
sudo docker run --name eth-parity -d -p 30300:30300 -p 8080:8080 -p 8180:8180 -p 8540:8540 -v ~/node.pwds:/build/node.pwds -v ~/parity-data:/tmp/parity -v ~/demo-spec.json:/build/demo-spec.json -v ~/node-to-enode.toml:/build/node-to-enode.toml ethcore/parity:stable --config node-to-enode.toml
