#!/bin/bash

echo "==============================================="
echo "  WINSNIP TOOLS NODE INSTALL EMPEIRIAS AUTO"
echo "==============================================="

cd $HOME
VER="1.22.3"
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

read -p "Enter your name wallet: " WALLET
read -p "Enter your moniker: " MONIKER
read -p "Enter your port number: " EMPED_PORT
echo "export WALLET=\"$WALLET\"" >> $HOME/.bash_profile
echo "export MONIKER=\"$MONIKER\"" >> $HOME/.bash_profile
echo "export EMPED_CHAIN_ID=\"empe-testnet-2\"" >> $HOME/.bash_profile
echo "export EMPED_PORT=\"$EMPED_PORT\"" >> $HOME/.bash_profile
source $HOME/.bash_profile

cd $HOME
curl -LO https://github.com/empe-io/empe-chain-releases/raw/master/v0.1.0/emped_linux_amd64.tar.gz
tar -xvf emped_linux_amd64.tar.gz
mv emped ~/go/bin

emped config node tcp://localhost:${EMPED_PORT}657
emped config keyring-backend os
emped config chain-id empe-testnet-2
emped init "$MONIKER" --chain-id empe-testnet-2

wget -O $HOME/.empe-chain/config/genesis.json https://server-5.itrocket.net/testnet/empeiria/genesis.json
wget -O $HOME/.empe-chain/config/addrbook.json  https://server-5.itrocket.net/testnet/empeiria/addrbook.json

SEEDS="20ca5fc4882e6f975ad02d106da8af9c4a5ac6de@empeiria-testnet-seed.itrocket.net:28656"
PEERS="03aa072f917ed1b79a14ea2cc660bc3bac787e82@empeiria-testnet-peer.itrocket.net:28656,004e2924efb660169e27d55518909b24f902dd48@155.133.27.170:26656,7f777a33fc94dfdade513c161a0bafbb0cfc2025@213.199.45.86:43656,5faa12744223fd0aea91970e405d69731ff35fed@62.169.17.9:43656,33cfcfa07ad55331d40fb7bcda010b0156328647@149.102.144.171:43656,3e30e4b87bdd45e9715b0bbf02c9930d820a3158@164.132.168.149:26656,bb15883943a2f31b1ca73247a1b0526a5778f23a@135.181.94.81:26656,e058f20874c7ddf7d8dc8a6200ff6c7ee66098ba@65.109.93.124:29056,0340080d68f88eb6944bd79c86abd3c9794eb0a0@65.108.233.73:13656,45bdc8628385d34afc271206ac629b07675cd614@65.21.202.124:25656,a9cf0ffdef421d1f4f4a3e1573800f4ee6529773@136.243.13.36:29056,878d0e8b9741adc865823e4f69554712e35236b9@91.227.33.18:13656"
sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" \
       -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" $HOME/.empe-chain/config/config.toml

sed -i.bak -e "s%:1317%:${EMPED_PORT}317%g;
s%:8080%:${EMPED_PORT}080%g;
s%:9090%:${EMPED_PORT}090%g;
s%:9091%:${EMPED_PORT}091%g;
s%:8545%:${EMPED_PORT}545%g;
s%:8546%:${EMPED_PORT}546%g;
s%:6065%:${EMPED_PORT}065%g" $HOME/.empe-chain/config/app.toml

sed -i.bak -e "s%:26658%:${EMPED_PORT}658%g;
s%:26657%:${EMPED_PORT}657%g;
s%:6060%:${EMPED_PORT}060%g;
s%:26656%:${EMPED_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${EMPED_PORT}656\"%;
s%:26660%:${EMPED_PORT}660%g" $HOME/.empe-chain/config/config.toml

sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.empe-chain/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.empe-chain/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"50\"/" $HOME/.empe-chain/config/app.toml

sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.0001uempe"|g' $HOME/.empe-chain/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.empe-chain/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.empe-chain/config/config.toml

sudo tee /etc/systemd/system/emped.service > /dev/null <<EOF
[Unit]
Description=Empeiria node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.empe-chain
ExecStart=$(which emped) start --home $HOME/.empe-chain
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

emped tendermint unsafe-reset-all --home $HOME/.empe-chain
if curl -s --head curl https://server-5.itrocket.net/testnet/empeiria/empeiria_2024-07-31_759028_snap.tar.lz4 | head -n 1 | grep "200" > /dev/null; then
  curl https://server-5.itrocket.net/testnet/empeiria/empeiria_2024-07-31_759028_snap.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.empe-chain
else
  echo "no snapshot founded"
fi

sudo systemctl daemon-reload
sudo systemctl enable emped
sudo systemctl restart emped && sudo journalctl -u emped -f
