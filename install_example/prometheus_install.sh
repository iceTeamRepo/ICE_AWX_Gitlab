#!/usr/bin/env bash

imds_token=$( curl -Ss -H "X-aws-ec2-metadata-token-ttl-seconds: 30" -XPUT 169.254.169.254/latest/api/token )
instance_id=$( curl -Ss -H "X-aws-ec2-metadata-token: $imds_token" 169.254.169.254/latest/meta-data/instance-id )
local_ipv4=$( curl -Ss -H "X-aws-ec2-metadata-token: $imds_token" 169.254.169.254/latest/meta-data/local-ipv4 )

sudo timedatectl set-timezone UTC

##--------------------------------------------------------------------
## AWS CLI 설치

install_aws_cli() {
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
}

install_aws_cli

##--------------------------------------------------------------------
## Prometheus 사용자 추가

add_prometheus_user() {
  USER_NAME="prometheus"
	USER_COMMENT="Prometheus user"
	USER_GROUP="prometheus"
	USER_HOME="/srv/prometheus"
	
    DIST=$(cat /etc/os-release | grep '^ID=')
    
    case $DIST in
    'ID=ubuntu' | 'ID=debian')
        if ! getent group $USER_GROUP >/dev/null
        then
          sudo addgroup --system $USER_GROUP >/dev/null
        fi
        
        if ! getent passwd $USER_NAME >/dev/null
        then
          sudo adduser \
            --system \
            --disabled-login \
            --ingroup "$USER_GROUP" \
            --home "$USER_HOME" \
            --no-create-home \
            --gecos "$USER_COMMENT" \
            --shell /bin/false \
            $USER_NAME  >/dev/null
        fi
        ;;
    'ID="centos"' | 'ID="rhel"' | 'ID="amzn"')
        sudo /usr/sbin/groupadd --force --system $USER_GROUP
        if ! getent passwd $USER_NAME >/dev/null ; then
          sudo /usr/sbin/adduser \
            --system \
            --gid "$USER_GROUP" \
            --home "$USER_HOME" \
            --no-create-home \
            --comment "$USER_COMMENT" \
            --shell /bin/false \
            $USER_NAME  >/dev/null
        fi
		    ;;
    *)
        echo "Unsupported distribution: $DIST"
        exit 1
        ;;		
    esac
}

add_prometheus_user


##--------------------------------------------------------------------
# Prometheus 설치

install_prometheus() { 
    curl -LO https://github.com/prometheus/prometheus/releases/download/v2.44.0/prometheus-2.44.0.linux-amd64.tar.gz
    tar -xvf prometheus-2.44.0.linux-amd64.tar.gz
    mv prometheus-2.44.0.linux-amd64 prometheus-files
    sudo mkdir /etc/prometheus
    sudo mkdir /var/lib/prometheus
    sudo cp prometheus-files/prometheus /usr/local/bin/
    sudo cp prometheus-files/promtool /usr/local/bin/
    sudo cp -r prometheus-files/consoles /etc/prometheus
    sudo cp -r prometheus-files/console_libraries /etc/prometheus
}

install_prometheus


##--------------------------------------------------------------------
## Prometheus 생성
 
create_service() {
    SYSTEMD_DIR=""
    DIST=$(cat /etc/os-release | grep '^ID=')
    
    case $DIST in
    'ID=ubuntu' | 'ID=debian')
        SYSTEMD_DIR="/lib/systemd/system"  
        ;;
    'ID="centos"' | 'ID="rhel"' | 'ID="amzn"')
        SYSTEMD_DIR="/etc/systemd/system"  
        ;;
    *)
        echo "Unsupported distribution: $DIST"
        exit 1
        ;;
    esac

    sudo tee $SYSTEMD_DIR/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF
    sudo chmod 0664 $SYSTEMD_DIR/prometheus.service
}

create_service


##--------------------------------------------------------------------
## Prometheus 구성 파일 생성

config_prometheus() {
    cat > /etc/prometheus/prometheus.yml << EOF
scrape_configs:
  - job_name: gitlab-rails #  gitlab-web 과 동일하므로 생략가능
    metrics_path: "/-/metrics"
    scheme: https
    static_configs:
      - targets:
        - gitlab.idtice.com
    tls_config:
      insecure_skip_verify: true
  - job_name: nginx
    static_configs:
      - targets:
        - "10.0.10.100:8060"
  - job_name: node
    static_configs:
      - targets:
        - "10.0.10.100:9100"
  - job_name: gitlab-workhorse
    static_configs:
      - targets:
        - "10.0.10.100:9229"
  - job_name: gitlab-sidekiq
    static_configs:
      - targets:
        - "10.0.10.100:8082"
  - job_name: gitlab_exporter_database
    metrics_path: "/database"
    static_configs:
      - targets:
        - "10.0.10.100:9168"
  - job_name: registry
    static_configs:
      - targets:
        - "10.0.10.100:5001"
  - job_name: praefect-gitaly
    static_configs:
      - targets:
        - "10.0.10.180:9236"
  - job_name: praefect
    static_configs:
      - targets:
        - "10.0.10.170:9652"

EOF
}

config_prometheus

##--------------------------------------------------------------------
## Prometheus 파일 및 디렉토리 퍼미션 설정

set_permissions() {
    sudo chown prometheus:prometheus /etc/prometheus
    sudo chown prometheus:prometheus /var/lib/prometheus
    sudo chown prometheus:prometheus /usr/local/bin/prometheus
    sudo chown prometheus:prometheus /usr/local/bin/promtool
    sudo chown -R prometheus:prometheus /etc/prometheus/consoles
    sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries    
    sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml
    sudo chown prometheus:prometheus /etc/prometheus/prometheus-token
}

set_permissions 


##--------------------------------------------------------------------
## Prometheus 서비스 실행
 
sudo systemctl enable prometheus
sudo systemctl start prometheus