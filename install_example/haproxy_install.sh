Content-Type: multipart/mixed; boundary="MIMEBOUNDARY"
MIME-Version: 1.0

--MIMEBOUNDARY
Content-Disposition: attachment; filename="init.cfg"
Content-Transfer-Encoding: 7bit
Content-Type: text/cloud-config
Mime-Version: 1.0

#cloud-config

runcmd:
- echo "Done"
--MIMEBOUNDARY
Content-Transfer-Encoding: 7bit
Content-Type: text/x-shellscript
Mime-Version: 1.0

#!/usr/bin/env bash

install_haproxy_and_configure() {
    # Install HAProxy
    sudo apt-get -yqq update &>/dev/null  
    sudo apt-get -yqq install haproxy &>/dev/null

    # Create the HAProxy configuration file
    # gitlab 문서는 오래된 haproxy 를 사용하고 있는 것으로 보이며 관련한 설정이 좀 봐뀌었다.
    #   바뀐 옵션 defautls 구성 및 bind 
    #    https://serverfault.com/questions/747895/bind-to-all-interfaces-for-ipv4-and-ipv6-in-haproxy
    sudo tee /etc/haproxy/haproxy.cfg > /dev/null <<EOF
global
    log /dev/log local0
    log localhost local1 notice

defaults
    log global
    default-server inter 3s fall 3 rise 2
    balance leastconn

listen stats
    mode http
    bind :::9000 v4v6
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if LOCALHOST

frontend internal-pgbouncer-tcp-in
    bind :::6432 v4v6
    mode tcp
    option tcplog
    default_backend pgbouncer

frontend internal-praefect-tcp-in
    bind :::2305 v4v6
    mode tcp
    option tcplog
    option clitcpka
    default_backend praefect

frontend internal-rails-tcp-in
    bind :::80 v4v6
    mode tcp
    option tcplog
    default_backend internalrails

backend pgbouncer
    mode tcp
    option tcp-check
    server pgbouncer1 10.0.10.140:6432 check

backend praefect
    mode tcp
    option tcp-check
    option srvtcpka
    server praefect1 10.0.10.170:2305 check

backend internalrails
    mode tcp
    option tcp-check
    server rails1 10.0.10.100:80 check

EOF

    # Optional: 특정 포트만 허용하려면 아래 Uncomment
    #iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    #iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    #iptables -A INPUT -p tcp --dport 2305 -j ACCEPT
    #iptables -A INPUT -p tcp --dport 6432 -j ACCEPT
    #iptables -A INPUT -j DROP
    #iptables-save > /etc/iptables.rules

    sudo systemctl daemon-reload
    sudo systemctl start haproxy
    sudo systemctl enable haproxy 
}

#-----------------------------------------------------------------------------------------------------------------------------------
# Gitaly, Praefect 설치 확인 
#-----------------------------------------------------------------------------------------------------------------------------------
check_secret_value_changed() {
  local secret_id=$1 
  local default_value= 'DEFAULT'

  local max_wait_time=1800
  local wait_interval=10
  local elapsed_time=0

  while [ $elapsed_time -lt $max_wait_time ]; do
      secret_value=$(aws secretsmanager get-secret-value --secret-id $secret_id --query SecretString --output text)

      if [ "$secret_value" != "$default_value" ]; then  
          return 0
      else
          echo "Wating..."
      fi

      sleep $wait_interval
      elapsed_time=$((elapsed_time + wait_interval))
  done

  return 1
}

wait_until_other_services_up() { 
  local praefect_status_id='gitlab-praefect-09237b12'
  local patroni_status_id='gitlab-patroni-96bef895'

  # patroni up 확인
  if ! check_secret_value_changed $patroni_status_id; then
      install_log "patroni staus check failed"
      exit 0
  fi

  # praefect up 확인
  if ! check_secret_value_changed $praefect_status_id; then
      install_log "praefect staus check failed"
      exit 0
  fi
}

check_service_status() {
    while true; do
        # haproxy 상태 확인
        status=$(sudo systemctl status haproxy | grep "active (running)")

        if [[ -z "$status" ]]; then
            sudo systemctl restart haproxy
        else
            wait_until_other_services_up

            sudo systemctl restart haproxy
            haproxy_output=$(sudo systemctl status haproxy)
            haproxy_set_vaild=$(sudo haproxy -c -f /etc/haproxy/haproxy.cfg)

            echo "$haproxy_set_vaild" | sudo tee /tmp/haproxy_check  > /dev/null
            echo "$haproxy_output" | sudo tee -a /tmp/haproxy_check  > /dev/null
            aws secretsmanager update-secret --secret-id "gitlab-haproxy-0333955b" --secret-string file:///tmp/haproxy_check
            return
        fi

        # 60초 대기 후 다시 확인
        sleep 60
    done
}



# 함수 호출
install_haproxy_and_configure
check_service_status
--MIMEBOUNDARY--
