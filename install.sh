if [ -z "$PORT" ]; then
  echo "环境变量 PORT 没有被设置。"
  exit 1
fi

if [ -z "$UUID" ]; then
  echo "环境变量 UUID 没有被设置。"
  exit 1
fi

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install-geodata


cat>/usr/local/etc/xray/config.json<<EOF
{
    "inbounds": [
        {
            "tag": "inbound",
            "port": $PORT,
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID",
                        "level": 1,
                        "alterId": 64
                    }
                ]
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        },
        {
            "protocol": "blackhole",
            "settings": {},
            "tag": "blocked"
        },
        {
            "tag": "proxy",
            "protocol": "socks",
            "settings": {
                "servers": [
                    {
                        "address": "127.0.0.1",
                        "port": 40000
                    }
                ]
            }
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "outboundTag": "proxy",
                "domain": [
                    "domain:openai.com"
                ]
            }
        ]
    },
    "log": {
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log",
        "loglevel": "warning",
        "dnsLog": true
    }
}
EOF


curl https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt -y update
sudo apt -y install cloudflare-warp

echo y|warp-cli register

warp-cli set-mode proxy

warp-cli connect

warp-cli enable-always-on

export ALL_PROXY=socks5://127.0.0.1:40000

systemctl stop xray.service

systemctl start xray.service

systemctl status xray.service
curl ifconfig.me -w "\n"

echo "Done!"
