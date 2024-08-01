#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' 

echo -e "${YELLOW}=================================================================="
echo -e "${CYAN}              WINSNIP TOOLS NODE INSTALL SYMPHONY AUTO            "
echo -e "${YELLOW}==================================================================${NC}"

echo "Updating packages and installing prerequisites..."
sudo apt update && sudo apt upgrade -y
sudo apt install curl git jq lz4 build-essential -y

echo "Configuring firewall..."
sudo ufw default allow outgoing
sudo ufw default deny incoming
sudo ufw allow ssh
sudo ufw allow 26656

sudo ufw enable

echo "Installing Go..."
VER="1.21.5"
sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go$VER.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> \$HOME/.bash_profile
source \$HOME/.bash_profile
go version

echo "Building binary from repository..."
cd $HOME
rm -rf symphony
git clone https://github.com/Orchestra-Labs/symphony
cd symphony
git checkout v0.2.1
make build

echo "Enter your node moniker (name):"
read MONIKER
echo "Initializing node with moniker: \$MONIKER"
symphonyd init \$MONIKER --chain-id symphony-testnet-2

echo "Configuring node settings..."
symphonyd init $MONIKER --chain-id symphony-testnet-2
symphonyd config keyring-backend file

echo "Adding genesis file and addrbook..."
sudo ln -s $HOME/.symphonyd/cosmovisor/genesis $HOME/.symphonyd/cosmovisor/current -f
sudo ln -s $HOME/.symphonyd/cosmovisor/current/bin/symphonyd /usr/local/bin/symphonyd -f

echo "Configuring seeds and peers..."
SEEDS="a68147995f2a2adf1cba1a43524b833fb66917a8@symphony.revonode.com:10656"
PEERS="\$(curl -sS https://rpc.symphony.revonode.com/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | sed -z 's|\n|,|g;s|.$||')"
sed -i -e "s|^seeds *=.*|seeds = '\$SEEDS'|; s|^persistent_peers *=.*|persistent_peers = '\$PEERS'|" \$HOME/.symphonyd/config/config.toml

echo "Configuring gas prices..."
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0note\"|" $HOME/.symphonyd/config/app.toml

echo "Configuring custom pruning..."
sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "19"|' \
  $HOME/.symphonyd/config/app.toml

echo "Creating service file..."
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

echo "Reloading and enabling service file..."
sudo systemctl daemon-reload
sudo systemctl enable symphonyd

echo "Downloading latest snapshot..."
sudo apt update
sudo apt install lz4
sudo systemctl stop symphonyd
symphonyd tendermint unsafe-reset-all --home $HOME/.symphonyd --keep-addr-book
curl -o - -L https://snapshots.polkachu.com/testnet-snapshots/symphony/symphony_172236.tar.lz4 | lz4 -c -d - | tar -x -C $HOME/.symphonyd


echo "Starting node..."
sudo systemctl start symphonyd && sudo journalctl -fu symphonyd -o cat
