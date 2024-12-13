#!/bin/bash

export PATH="/usr/bin:$PATH"
PUBLIC_IP_ADDRESS=$(ec2-metadata --public-ipv4 | cut -d " " -f 2);

echo 'PUBLIC_IP_ADDRESS: '$PUBLIC_IP_ADDRESS''
sudo sed -i s/log.dirs=\\/tmp\\/kraft-combined-logs/log.dirs=config\\/kraft\\/logs/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/num.partitions=1/num.partitions=3/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/offsets.topic.replication.factor=1/offsets.topic.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/transaction.state.log.replication.factor=1/transaction.state.log.replication.factor=2/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.receive.buffer.bytes=102400/socket.receive.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/socket.send.buffer.bytes=102400/socket.send.buffer.bytes=1048576/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/controller.quorum.voters=1@localhost:9093/controller.quorum.voters=1@$PUBLIC_IP_ADDRESS:9093/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listeners=PLAINTEXT:\\/\\/:9092,CONTROLLER:\\/\\/:9093/listeners=SASL_SSL:\\/\\/$PUBLIC_IP_ADDRESS:9092,CONTROLLER:\\/\\/$PUBLIC_IP_ADDRESS:9093/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/inter.broker.listener.name=PLAINTEXT/inter.broker.listener.name=SASL_SSL/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/advertised.listeners=PLAINTEXT:\\/\\/localhost:9092,CONTROLLER:\\/\\/localhost:9093/advertised.listeners=SASL_SSL:\\/\\/$PUBLIC_IP_ADDRESS:9092/ /opt/kafka/config/kraft/server.properties
sudo sed -i s/listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/listener.security.protocol.map=CONTROLLER:SASL_SSL,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL/ /opt/kafka/config/kraft/server.properties

# Prometheus
sudo useradd --no-create-home prometheus || echo "User already exists."
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
wget https://github.com/prometheus/prometheus/releases/download/v3.0.1/prometheus-2.37.0.linux-amd64.tar.gz
tar xzf prometheus-2.37.0.linux-amd64.tar.gz
sudo cp prometheus-2.37.0.linux-amd64/prometheus /usr/local/bin
sudo cp prometheus-2.37.0.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-2.37.0.linux-amd64/consoles /etc/prometheus
sudo cp -r prometheus-2.37.0.linux-amd64/console_libraries /etc/prometheus
sudo cp prometheus-2.37.0.linux-amd64/promtool /usr/local/bin/
rm -rf prometheus-2.37.0.linux-amd64.tar.gz prometheus-2.37.0.linux-amd64
# sudo sh -c 'cat << EOF >> /etc/prometheus/prometheus.yml
#   - job_name: 'kafka'
#     static_configs:
#     - targets: ['$PUBLIC_IP_ADDRESS:7075']
# EOF'
sudo touch /etc/systemd/system/prometheus.service
sudo chown prometheus:prometheus /etc/systemd/system/prometheus.service
sudo cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries[Install]
WantedBy=multi-user.target
EOF

sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
sudo chown -R prometheus:prometheus /var/lib/prometheus

sudo systemctl daemon-reload
sudo systemctl restart kafka
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus
sudo systemctl list-unit-files --type=service



