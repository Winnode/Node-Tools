#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' 

echo -e "${YELLOW}=================================================================="
echo -e "${CYAN}              WINSNIP TOOLS NODE INSTALL EMPEIRIAS AUTO            "
echo -e "${YELLOW}==================================================================${NC}"

read -p "${GREEN}Enter your moniker name: ${NC}" MONIKER
read -p "${GREEN}Enter your custom base port number (e.g., 111): ${NC}" CUSTOM_PORT

sudo apt update && sudo apt upgrade -y
sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y

cd $HOME
VER="1.22.3"
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=\$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

mkdir -p $HOME/.empe-chain/cosmovisor/genesis/bin
wget https://github.com/empe-io/empe-chain-releases/raw/master/v0.1.0/emped_linux_amd64.tar.gz
tar -xvf emped_linux_amd64.tar.gz
rm -rf emped_linux_amd64.tar.gz
chmod +x emped
mv emped $HOME/.empe-chain/cosmovisor/genesis/bin/
sudo ln -s $HOME/.empe-chain/cosmovisor/genesis $HOME/.empe-chain/cosmovisor/current -f
sudo ln -s $HOME/.empe-chain/cosmovisor/current/bin/emped /usr/local/bin/emped -f
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0

sudo tee /etc/systemd/system/emped.service > /dev/null << EOF
[Unit]
Description=empe-chain node service
After=network-online.target

[Service]
User=\$USER
ExecStart=\$(which cosmovisor) run start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=\${HOME}/.empe-chain"
Environment="DAEMON_NAME=emped"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:\$HOME/.emped/cosmovisor/current/bin"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable emped

emped init "\$MONIKER" --chain-id empe-testnet-2

wget -O $HOME/.empe-chain/config/genesis.json "https://raw.githubusercontent.com/empe-io/empe-chains/master/testnet-2/genesis.json"
wget -O $HOME/.empe-chain/config/addrbook.json "https://raw.githubusercontent.com/MictoNode/empe-chain/main/addrbook.json"

sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0001uempe\"/;" ~/.empe-chain/config/app.toml
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.empe-chain/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.empe-chain/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.empe-chain/config/app.toml
sed -i "s/^indexer *=.*/indexer = \"null\"/" $HOME/.empe-chain/config/config.toml

echo "export CUSTOM_PORT=\"\$CUSTOM_PORT\"" >> $HOME/.bash_profile
source $HOME/.bash_profile

sed -i.bak -e "s%:1317%:${CUSTOM_PORT}17%g; \
s%:8080%:${CUSTOM_PORT}80%g; \
s%:9090%:${CUSTOM_PORT}90%g; \
s%:9091%:${CUSTOM_PORT}91%g; \
s%:8545%:${CUSTOM_PORT}45%g; \
s%:8546%:${CUSTOM_PORT}46%g; \
s%:6065%:${CUSTOM_PORT}65%g" $HOME/.empe-chain/config/app.toml

sed -i.bak -e "s%:26658%:${CUSTOM_PORT}58%g; \
s%:26657%:${CUSTOM_PORT}57%g; \
s%:6060%:${CUSTOM_PORT}60%g; \
s%:26656%:${CUSTOM_PORT}56%g; \
s%^external_address = \"\"%external_address = \"\$(wget -qO- eth0.me):${CUSTOM_PORT}56\"%; \
s%:26660%:${CUSTOM_PORT}60%g" $HOME/.empe-chain/config/config.toml

sudo systemctl restart emped
journalctl -fu emped -o cat
