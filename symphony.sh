#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' 

echo -e "${YELLOW}=================================================================="
echo -e "${CYAN}              WINSNIP TOOLS NODE INSTALL SYMPHONY AUTO            "
echo -e "${YELLOW}==================================================================${NC}"

is_port_in_use() {
    netstat -tuln | grep ":$1" > /dev/null
    return $?
}

read -p "Enter your moniker name: " MONIKER

sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go1.21.1.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)

cd $HOME
rm -rf symphony
git clone https://github.com/Orchestra-Labs/symphony
cd symphony
git checkout v0.2.1
make build

mkdir -p $HOME/.symphonyd/cosmovisor/genesis/bin
mv build/symphonyd $HOME/.symphonyd/cosmovisor/genesis/bin/
rm -rf build

sudo ln -s $HOME/.symphonyd/cosmovisor/genesis $HOME/.symphonyd/cosmovisor/current -f
sudo ln -s $HOME/.symphonyd/cosmovisor/current/bin/symphonyd /usr/local/bin/symphonyd -f

go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0

sudo tee /etc/systemd/system/symphony.service > /dev/null << EOF
[Unit]
Description=symphony node service
After=network-online.target
 
[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.symphonyd"
Environment="DAEMON_NAME=symphonyd"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:$HOME/.symphonyd/cosmovisor/current/bin"
 
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable symphony

symphonyd config chain-id symphony-testnet-2
symphonyd config keyring-backend test
symphonyd config node tcp://localhost:24857
symphonyd init $MONIKER --chain-id symphony-testnet-2

curl -Ls https://snap.nodex.one/symphony-testnet/genesis.json > $HOME/.symphonyd/config/genesis.json
curl -Ls https://snap.nodex.one/symphony-testnet/addrbook.json > $HOME/.symphonyd/config/addrbook.json

sed -i -e "s|^seeds *=.*|seeds = \"d1d43cc7c7aef715957289fd96a114ecaa7ba756@testnet-seeds.nodex.one:24810\"|" $HOME/.symphonyd/config/config.toml

sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0note\"|" $HOME/.symphonyd/config/app.toml

sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "19"|' \
  $HOME/.symphonyd/config/app.toml

read -p "Enter a custom RPC port (default 24857, press ENTER to skip): " CUSTOM_PORT
CUSTOM_PORT=${CUSTOM_PORT:-24857}

if is_port_in_use $CUSTOM_PORT; then
    echo "Port $CUSTOM_PORT is already in use. Please select a different port."
    exit 1
else
    sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:$((CUSTOM_PORT + 1))\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:$CUSTOM_PORT\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:$((CUSTOM_PORT + 103))\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:$((CUSTOM_PORT - 1))\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":$((CUSTOM_PORT + 9))\"%" $HOME/.symphonyd/config/config.toml
    echo "Custom RPC port set to $CUSTOM_PORT"
fi

echo "Downloading the latest chain snapshot..."
curl -L https://snap.nodex.one/symphony-testnet/symphony-latest.tar.lz4 | tar -Ilz4 -xf - -C $HOME/.symphonyd
if [[ -f $HOME/.symphonyd/data/upgrade-info.json ]]; then
    cp $HOME/.symphonyd/data/upgrade-info.json $HOME/.symphonyd/cosmovisor/genesis/upgrade-info.json
fi

echo "Starting symphony service..."
sudo systemctl start symphony
echo "Symphony node has been successfully started with RPC port $CUSTOM_PORT!"
