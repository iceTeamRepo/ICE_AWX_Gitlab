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

#!/bin/bash

install_log() {
  local message="$1"

  # Check if the file exists
  if [ ! -f "/tmp/install_log.sh" ]; then
    # If the file does not exist, create it
    touch "/tmp/install_log.sh"
  fi

  # Append the message to the file
  echo "$message" >> "/tmp/install_log.sh"
}

#-----------------------------------------------------------------------------------------------------------------------------------
# check_os :  운영 체제 종류를 확인하고, Ubuntu 또는 Amazon Linux에서 실행 중임을 확인한 후에 필요한 설정을 진행
#-----------------------------------------------------------------------------------------------------------------------------------
check_os() {
  install_log "check_os"
  name=$(cat /etc/os-release | grep ^NAME= | sed 's/"//g')
  clean_name=${name#*=}

  version=$(cat /etc/os-release | grep ^VERSION_ID= | sed 's/"//g')
  clean_version=${version#*=}
  major=${clean_version%.*}
  minor=${clean_version#*.}
  
  if [[ "$clean_name" == "Ubuntu" ]]; then
    operating_system="ubuntu"
  elif [[ "$clean_name" == "Amazon Linux" ]]; then
    operating_system="amazonlinux"
  else
    operating_system="undef"
  fi

  echo "OS: $operating_system"
  echo "OS Major Release: $major"
  echo "OS Minor Release: $minor"
}

#-----------------------------------------------------------------------------------------------------------------------------------
# migrate_and_configure_db :  
#   첫 번째 rails 노드에서만 진행해야 한다.
#   또한, 첫 번째 노드에서 데이터베이스 마이그레이션을 진행할 때 Pgbouncer가 아닌 Postgresql Leader 노드에 직접 연결되도록 수정해야 한다. 
#   그 후 reconfigure 후 다시 Pgbouncer를 바라보게 수정해야 한다.
#-----------------------------------------------------------------------------------------------------------------------------------
configure_gitlab_db_with_retry() {
  local max_retries=3
  local retry_delay=30
  local retries=0
  local log_file="/tmp/leader_node_db_migration_log.txt"
  
  sleep $retry_delay

  while [ $retries -lt $max_retries ]; do
    sudo rm -rf $log_file
    sudo gitlab-rake gitlab:db:configure > $log_file 2>&1
    
    if grep -q "cannot execute CREATE SCHEMA in a read-only transaction" $log_file; then
      install_log "Error encountered: 'Cannot execute CREATE SCHEMA in a read-only transaction'. Retrying in $retry_delay seconds..."
      ((retries++))
      sleep $retry_delay
    else
      install_log "Database configuration completed successfully."
      return 0  # Success
    fi
  done

  install_log "Database configuration failed after $max_retries retries."
  return 1  # Failure
}

migrate_and_configure_db() {
  install_log "migrate_and_configure_db"

  sudo touch /etc/gitlab/skip-auto-reconfigure

    # 현재 구성 기준으로 reconfigure
  sudo gitlab-ctl reconfigure

  # DB Migration 수행
  configure_gitlab_db_with_retry

  # patroni master 노드로 설정 변경한 사항을 다시 되돌림 
  sed -i "s/^\( *gitlab_rails\['db_host'\] = .*\)$/# \1/" "/etc/gitlab/gitlab.rb"
  sed -i "s/^\( *gitlab_rails\['db_port'\] = .*\)$/# \1/" "/etc/gitlab/gitlab.rb"
  echo "gitlab_rails['db_host'] = '10.0.10.110'" >> "/etc/gitlab/gitlab.rb"
  echo "gitlab_rails['db_port'] = 6432" >> "/etc/gitlab/gitlab.rb"

  # 다시 reconfigure
  sudo gitlab-ctl reconfigure
  }

#-----------------------------------------------------------------------------------------------------------------------------------
# configure_gitlab_reload : Gitlab reconfigure 및 재시작
#-----------------------------------------------------------------------------------------------------------------------------------
configure_gitlab_reload() {
  install_log "configure_gitlab_reload"
  sudo gitlab-ctl reconfigure
  sudo gitlab-ctl restart
}

#-----------------------------------------------------------------------------------------------------------------------------------
# configure_geo : Geo 동기화 작업
#-----------------------------------------------------------------------------------------------------------------------------------
configure_geo() {
  install_log "configure_geo"



}

#-----------------------------------------------------------------------------------------------------------------------------------
# generate_gitlab_registry_ssl_cert : Gitlab Registry SSL 인증서 생성
#-----------------------------------------------------------------------------------------------------------------------------------
generate_gitlab_registry_ssl_cert() { 
  mkdir -p /etc/gitlab/ssl
  chmod 700 /etc/gitlab/ssl
  chown root:root /etc/gitlab/ssl

  # Generate SSL certificate
  openssl req -x509 -newkey rsa:4096 -keyout /etc/gitlab/ssl/registry.gitlab.idtice.com.key -out /etc/gitlab/ssl/registry.gitlab.idtice.com.crt -days 365 -nodes -subj "/CN=registry.gitlab.idtice.com"

  # Set correct permissions
  chmod 600 /etc/gitlab/ssl/registry.gitlab.idtice.com.key
  chown root:root /etc/gitlab/ssl/registry.gitlab.idtice.com.key
  chown root:root /etc/gitlab/ssl/registry.gitlab.idtice.com.crt
}


#-----------------------------------------------------------------------------------------------------------------------------------
# configure_gitlab_rb : Gitlab RB 파일 생성
#-----------------------------------------------------------------------------------------------------------------------------------
configure_gitlab_rb() {
  install_log "configure_gitlab_rb"

  generate_gitlab_registry_ssl_cert

  cat <<-EOF | tee /etc/gitlab/gitlab-license
eyJkYXRhIjoibkVyb01sQkxqSVZ4S1RxY0FseEpLZUFiS2YrQUVySldDMXZu
OWt2UnMrZFVyRnpEeXpPSEpwYWs4emtIXG52dzh5cWVacmw1dFlwbFlsaTZv
TVFReVBWTlRGWFJzVEdMNjk5clRhVmRzblZBY3g5aitTdWtFc1ZYT0RcbnhT
d0FjWkdKVXhtYVJ6RGRKMURRVzNDNE56WE9tQnZJcGplZXhLM0tNMU5xamY4
TVM5dDF2RE1XaHA4WVxuakFJaXRESXpFMUtEMnBSVG4zSzBCSTNlREVQREVj
MGxDQnZ4WFFLMWZTYmliNjVCMnNuOUFhQXRaSVhVXG51V1dyVjFSV3JpbDN6
MFMwbnhGN01EODdxMXZ4UmhTQ1p5T0U2aWFLbzh2ZkN5VGVENTNCVCtoWm1U
VzBcbnBGNHRBN0Z0N296MDlHUmRGU2g1NVlGTlZtNlY0TC9aRGxmVlI0WTVY
WmZ1aDM5c0ZMb1RBUzh0VEVVZ1xudGFicmZjbmNTOXcvaXcxVjIrMjVXaTk1
Z2luNTVFVy9vRjhuajVZZlVJYkd0c2FMMG9laEJrN2w2cVNHXG5oaU85NVZt
SnJWaDUrL0JuV1pYSlpMOVpKQnR0aWNXSEgyWktld2ppaENIclFneTAzTnJT
NGdzTURrV1VcbmJHem9CMzR3bVpIeU5Xa3NveEdnNytOOWxGZnpFcSt4cEpt
N3dyWnRpc01QSTVaa1N5T09OYXRLK1k4K1xuT20xNUx6ZmZBSTdLUDlKYnF1
NHhhNlRIaW9iT2tVTnlVbnVjbU0xQ2F5OEwxaklVK3B6bXhyOVVtVGoxXG4y
bTM5dkJhUVMrZUJRZ2xVNmI1eDJDS2ZndTJha1ltTDl2TXlaYlBEN1lCWUhk
RDREWWx4Z0pVYVpabStcbnphVUFDY0NpN0k4ajYvckRESXY2QndNT0tqdU1E
UTBtM09XQUpuTHk1M1ZMNlNuNi9YNkkxcUJNcGorbFxuWFFnQlViTDdic1pm
dDhkVE8rYjBxNkxxWElRTDVsd0h0Vk5QaC81SmRueDJ2Ty9jd0lram5iakFY
Zmk0XG5IZDZOZEpWTWZsYTNsL1JwTGRFSVRCOS90aXp4UVIxV0Qzc0J4K3JE
YW1XTHErTzNRVUdDNUllQWVLZEZcbm9KeTRXQzE2cEo3UU14M0hpNG5FVXpk
VFZndjhFZWd0SHFZaG9FL3VqNlF3YmVCTFFzdTNubXE1NkQ0U1xudzRKVG96
enMwTE5wMnloamhKV1Y4UGVrbkVxaVpoU1RScGN0VkxVRGMzdG8vUG5zVHFF
K2JIYWVOdkRsXG5nbG5CTm9CWjV0ajJtMWhjakwyVFpPR1NtdVJmT09RVU8y
ZEpoRHBIbDF2M2ltK0c5R1pVYVFadDRFNDlcbk9nRTZaRTBsK3dDQWZJcUdV
TThZYXVxL244ckFQbGZLcVk2UEd3aU53R3dCY3daYWlBVWZoek1aM21md1xu
amZrbW8xODdoVG9tZThScU4rZVRlTUFNUitlSFV2ajltZFMrYjdldWNSWHZE
VlRPWlJ2ZXl0Tlo4Q01xXG5UaVRLc1hjTll0NFhDOTRGRDd5cU5odVpUcGtY
ejRma3l5RU5xRWVMUTU4bFI3WHFjaXdNck1nQVJPbXVcbnJINlFsaEp0YzQ2
SzRSajNuSTg0U0tsSnEvTzdvUVhEeVpvUkdncGNnakdBODZPbkl5MzcvL2hl
NWJCNlxuQnlKbitxejNpNjFhcFR4T3A1SjFxMjhhTGEwRk1YVytzWk9ZS1hp
ODBSSmtMd3VtZ3RqbHpFVDFVSlMxXG5HSC9tSGxFSXR0YU41OVZXTkphZHEz
SVNESGhESWRFN0xLNEJDSEkyNUIrNXhveVZWNEJvUVFMQVlodjVcbi96L1N1
a2xpOXJxN1NEQzE1MFBqSmdVYWJ2M2FRZU5Oa0E5M3h0S01Hd01zS0NkWmxt
ZFNNQVJRRjN2NFxuZnVWMS9kc3A3SnpSNk5WcUtZYmtWczMxazRNZGNQMkJh
bmxZTUxNeUpuTlFINDRnSjVJYXVlWDFGVlQwXG53RHJEZ3NGcFJiUXg5RmRS
SjRwYUFWeDArS0JzdkYwNEIvK0ZKTUVqK2tYRit5bStaeXMxZ3ZLUkcwZXpc
bmJVUkx5ZysvTEtGY3dRZ0REZzg9XG4iLCJrZXkiOiJZdFlIT2ozRWtOQlcv
Y2gwSlk4SCtVWXNodC8rdDlkbS84aHZxT3lJSTNnb2xDR2dLZHVJNW96TW5i
Z2VcbnZEaHhkaHBjSXdBdHBmaFZ5SE9zc3hOZDdtd2dFb3BPWnpNM2FVcEsz
eUpRNWUrZHZnSFBnaS9DYi9TNFxuTWc1ZlhoZUJaOUxEQlQ1Y0xHLzZGN0pC
eEZiTVBWeEs1OFA3NXUxTi90M0IycjROTFMxUGg0dlZBazVlXG5zWVRzZmRv
ckU2eHpISkZjT3JOb1I2Tys4ZHJkNlY4WHFkZXBRZ0JuTkVzVmk1OTRldTRF
RU9oaUFzb3dcbnVMMU1Icks1Qmd4U2NsdFo0ZXNzVTlBNm5rVjZKQ1NzR3pt
UVJ5cWRtT3FKcFpmSHlnTm9YcXhYbGYvWFxuQmV1ckg2dDArSTErRHQ4Mzla
d2VzQXh6Ti9MeWl3U0VCV2hRYlhVTC9nPT1cbiIsIml2IjoibzNFUlFlSlNr
eExWeHg3OCtuQVlGQT09XG4ifQ==
EOF
 
  local patroni_leader_ip=$(aws secretsmanager get-secret-value --secret-id "gitlab-patroni_leader_ip-989bd4bd" --query SecretString --output text)

  rm -rf /etc/gitlab/gitlab.rb
  
  cat <<-EOF >> /etc/gitlab/gitlab.rb
################################################################################
## Rails
################################################################################
external_url 'https://gitlab.idtice.com'
gitlab_rails['auto_migrate'] = false
#gitlab_rails['time_zone'] = 'Asia/Seoul'

################################################################################
## Roles
################################################################################
roles(['application_role','sidekiq_role'])

################################################################################
## Storage
################################################################################
gitaly['enable'] = false
#git_data_dirs(
#  {
#    "default" => {
#      "gitaly_address" => "tcp://10.0.10.110:2305",
#      "gitaly_token" => "PRAEFECT_EXTERNAL_TOKEN"
#    }, 
#  }
#)
gitlab_rails['repositories_storages'] = {
  'default'  => { 'gitaly_address' => 'tcp://10.0.10.110:2305', 'gitaly_token' => 'PRAEFECT_EXTERNAL_TOKEN' }, 
}

################################################################################
## DB
################################################################################
gitlab_rails['db_host'] = '$patroni_leader_ip'
gitlab_rails['db_port'] = 5432

gitlab_rails['db_password'] = 'psqlpassword'
gitlab_rails['db_load_balancing'] = { 'hosts' => ['10.0.10.130', '10.0.11.130'] } # PostgreSQL IPs

################################################################################
## Redis
################################################################################
redis['master_name'] = 'gitlab-redis'
redis['master_password'] = 'redispassword'
gitlab_rails['redis_sentinels'] = [
    {'host' => '10.0.10.150', 'port' => 26379},
]

################################################################################
## Object Storage
################################################################################
gitlab_rails['object_store']['enabled'] = true
gitlab_rails['object_store']['connection'] = {
  'provider' => 'AWS',
  'region' => 'ap-northeast-2',
  'use_iam_profile' => true
}
#gitlab_rails['object_store']['storage_options'] = {
#  'server_side_encryption' => 'aws:kms',
#  'server_side_encryption_kms_key_id' => 'arn:aws:kms:ap-northeast-2:960249453675:key/5e67a1a0-0442-4d45-97b2-d3b3551e43cb'
#}
gitlab_rails['object_store']['proxy_download'] = true
gitlab_rails['object_store']['objects']['artifacts']['bucket'] = 'gitlab-s3-4c8f91ea-artifacts'
gitlab_rails['object_store']['objects']['external_diffs']['bucket'] = 'gitlab-s3-4c8f91ea-artifacts' #'gitlab-s3-4c8f91ea-external-diffs'
gitlab_rails['object_store']['objects']['lfs']['bucket'] = 'gitlab-s3-4c8f91ea-artifacts' #'gitlab-s3-4c8f91ea-lfs-objects'
gitlab_rails['object_store']['objects']['uploads']['bucket'] = 'gitlab-s3-4c8f91ea-artifacts' #'gitlab-s3-4c8f91ea-uploads'
gitlab_rails['object_store']['objects']['packages']['bucket'] = 'gitlab-s3-4c8f91ea-artifacts' #'gitlab-s3-4c8f91ea-packages'
gitlab_rails['object_store']['objects']['dependency_proxy']['bucket'] = 'gitlab-s3-4c8f91ea-artifacts' #'gitlab-s3-4c8f91ea-dependency-proxy'
gitlab_rails['object_store']['objects']['terraform_state']['bucket'] = 'gitlab-s3-4c8f91ea-artifacts' #'gitlab-s3-4c8f91ea-terraform-state'
gitlab_rails['object_store']['objects']['ci_secure_files']['bucket'] = 'gitlab-s3-4c8f91ea-artifacts' #'gitlab-s3-4c8f91ea-ci-secure-files'
gitlab_rails['object_store']['objects']['pages']['bucket'] = 'gitlab-s3-4c8f91ea-artifacts' #'gitlab-s3-4c8f91ea-pages'
 
gitlab_rails['backup_upload_connection'] = {
  'provider' => 'AWS',
  'region' => 'ap-northeast-2',
  'use_iam_profile' => true
}
#gitlab_rails['backup_upload_storage_options'] = {
#  'server_side_encryption' => 'aws:kms',
#  'server_side_encryption_kms_key_id' => 'arn:aws:kms:ap-northeast-2:960249453675:key/5e67a1a0-0442-4d45-97b2-d3b3551e43cb'
#}
gitlab_rails['backup_upload_remote_directory'] = 'gitlab-s3-4c8f91ea-backup'

gitlab_rails['ci_secure_files_object_store_connection'] = {
  'provider' => 'AWS',
  'region' => 'ap-northeast-2',
  'use_iam_profile' => true
}
gitlab_rails['ci_secure_files_object_store_enabled'] = true
gitlab_rails['ci_secure_files_object_store_remote_directory'] = 'gitlab-s3-4c8f91ea-ci-secure-files'


################################################################################
## Consul
################################################################################
consul['enable'] = true
consul['monitoring_service_discovery'] =  true
consul['configuration'] = {
   retry_join: %w(10.0.10.120 10.0.11.120 10.0.12.120)
}

################################################################################
## Email
################################################################################
#gitlab_rails['gitlab_email_enabled'] = true
#gitlab_rails['gitlab_email_from'] = 'noreply@gitlab.idtice.com'
#gitlab_rails['gitlab_email_display_name'] = 'GitLab'
#gitlab_rails['gitlab_email_reply_to'] = 'noreply@gitlab.idtice.com'
 
################################################################################
## GitLab Nginx
################################################################################
nginx['enable'] = true
nginx['listen_port'] = 80
nginx['listen_https'] = false

################################################################################
## GitLab Pages
################################################################################
pages_nginx['enable'] = true
pages_external_url 'https://pages.gitlab.idtice.com/'
pages_nginx['listen_port'] = 7080
pages_nginx['listen_https'] = false

################################################################################
## Container Registry settings
################################################################################
registry_nginx['enable'] = true
registry_external_url 'https://registry.gitlab.idtice.com'
registry_nginx['listen_port'] = 7090
registry_nginx['listen_https'] = true
registry_nginx['ssl_certificate'] = '/etc/gitlab/ssl/registry.gitlab.idtice.com.crt'
registry_nginx['ssl_certificate_key'] = '/etc/gitlab/ssl/registry.gitlab.idtice.com.key'
registry['registry_http_addr'] = '0.0.0.0:5000'

################################################################################
## gitlab sshd
################################################################################
gitlab_sshd['enable'] = true
gitlab_sshd['listen_address'] = '[::]:22'
gitlab_rails['gitlab_ssh_host'] = 'ssh.gitlab.idtice.com'
gitlab_rails['gitlab_ssh_user'] = ''

################################################################################
## sidekiq
################################################################################
sidekiq['enable'] = true
sidekiq['queue_groups'] = ['*'] * 4
sidekiq['listen_address'] = "0.0.0.0"

################################################################################
## psql
################################################################################
postgresql['enable'] = false

################################################################################
## puma
################################################################################
puma['listen'] = '0.0.0.0'

################################################################################
## License
################################################################################
gitlab_rails['initial_license_file'] = '/etc/gitlab/gitlab-license'

################################################################################
## External Prometheus Monitoring
################################################################################
prometheus['enable'] = false
prometheus_monitoring['enable'] = false

gitlab_rails['prometheus_address'] = '10.0.10.190:9090'
prometheus['listen_address'] = '0.0.0.0:9090'
gitlab_workhorse['prometheus_listen_addr'] = '0.0.0.0:9229'

node_exporter['listen_address'] = '0.0.0.0:9100'
gitlab_exporter['listen_address'] = '0.0.0.0'
gitlab_exporter['listen_port'] = '9168'
registry['debug_addr'] = '0.0.0.0:5001'

gitlab_exporter['enable'] = true
node_exporter['enable'] = true
 
nginx['status'] = {
  "listen_addresses" => ["0.0.0.0"],
  #"fqdn" => "dev.example.com",
  "port" => 8060,
  "options" => {
    "server_tokens" => "off",
    "access_log" => "on",
    "allow" => "10.0.10.190", 
    "deny" => "all"
  }
}
gitlab_rails['monitoring_whitelist'] = ['0.0.0.0/0', '::1/128']

EOF
}

#-----------------------------------------------------------------------------------------------------------------------------------
# copy_ssh_keys : gitlab-sshd 활성화하는 경우 gitlab 에 의해 생성된 호스트 키가 OpenSSH 호스트 키와 다르기 때문에 호스트 키 경고가 뜸
#                 https://docs.gitlab.com/ee/administration/operations/gitlab_sshd.html
#-----------------------------------------------------------------------------------------------------------------------------------
copy_ssh_keys() {
  install_log "copy_ssh_keys"

  # 기존 OpenSSH 키가 있는 디렉토리와 GitLab SSH 디렉토리
  local ssh_dir="/etc/ssh"
  local gitlab_sshd_dir="/var/opt/gitlab/gitlab-sshd"

  # 디렉토리가 존재하는지 확인
  if [ -d "$ssh_dir" ] && [ -d "$gitlab_sshd_dir" ]; then  
      sudo cp "$ssh_dir"/ssh_host_* "$gitlab_sshd_dir/"
  fi

  sudo systemctl restart sshd
}

#-----------------------------------------------------------------------------------------------------------------------------------
# 상태 확인
#-----------------------------------------------------------------------------------------------------------------------------------
gitlab_status_report() {
  install_log "gitlab_status_report"

    
  local attempt=0
  local max_attempts=5

  while true; do
    rm -rf /etc/gitlab/gitlab_check

    # gitlab-rake gitlab:check 실행
    echo "====== gitlab-rake gitlab:check ======" >> /etc/gitlab/gitlab_check
    sudo gitlab-rake gitlab:check 2>&1 | sudo tee -a /etc/gitlab/gitlab_check

    # Geo가 설정된 경우 gitlab-rake gitlab:geo:check 실행
    
    # 파일에 'error' 문자열이 있으면 다시 시도, 없으면 종료
    if ! grep -qi 'error' /etc/gitlab/gitlab_check; then
      install_log "No error while checking GitLab status."
      break
    fi

    # 최대 시도 횟수를 초과하면 종료
    if (( attempt >= max_attempts )); then
      install_log "Timeout reached (300 seconds) while checking GitLab status."
      break
    fi

    # 60초 대기 후 재시도
    attempt=$((attempt + 1))
    install_log "Error found in GitLab check, retrying... (Attempt #$attempt)"
    sleep 60
  done

  aws secretsmanager update-secret --secret-id "gitlab-rails-d6d1ab29" --secret-string file:///etc/gitlab/gitlab_check

  }


#-----------------------------------------------------------------------------------------------------------------------------------
# 다른 서비스들 모두 올라온 다음 진행하기 위한 대기 함수
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
  local consul_status_id='gitlab-consul-d6643f38'
  local gitaly_status_id='gitlab-gitaly-8a9fdef2'
  local praefect_status_id='gitlab-praefect-09237b12'
  local patroni_status_id='gitlab-patroni-96bef895'
  local haproxy_status_id='gitlab-haproxy-0333955b'
  local tracking_status_id=''

    
  # haproxy up 확인 
  if ! check_secret_value_changed $haproxy_status_id; then
      install_log "haproxy staus check failed"
      exit 0
  fi

  # consul up 확인 
  if ! check_secret_value_changed $consul_status_id; then
      install_log "consul staus check failed"
      exit 0
  fi

  # patroni up 확인
  if ! check_secret_value_changed $patroni_status_id; then
      install_log "patroni staus check failed"
      exit 0
  fi
 
  # gitaly up 확인
  if ! check_secret_value_changed $gitaly_status_id; then
      install_log "gitaly staus check failed"
      exit 0
  fi

  # praefect up 확인
  if ! check_secret_value_changed $praefect_status_id; then
      install_log "praefect staus check failed"
      exit 0
  fi

  # tracking db up 확인
  
  install_log "wait_until_other_services_up"
}

#-----------------------------------------------------------------------------------------------------------------------------------
# gitlab-secrets.json 파일 일치시키기
#-----------------------------------------------------------------------------------------------------------------------------------
update_gitlab_secrets() {
  local secret_id=$1 
  local default_value='DEFAULT'
  local secret_value

  # 비밀 값이 변경되었는지 확인
  if check_secret_value_changed "$secret_id"; then
    # AWS Secrets Manager에서 비밀 값 가져오기
    secret_value=$(aws secretsmanager get-secret-value --secret-id "$secret_id" --query SecretString --output text)
    
    # 비밀 값이 비어 있지 않으면 파일에 저장
    if [ -n "$secret_value" ]; then
      # 기존 GitLab 시크릿 파일 삭제
      rm -rf /etc/gitlab/gitlab-secrets.json
      
      # 새로운 비밀 값으로 파일 업데이트
      sudo tee /etc/gitlab/gitlab-secrets.json > /dev/null <<EOF
$secret_value
EOF
      sudo chown root:root /etc/gitlab/gitlab-secrets.json
      sudo chmod 0600 /etc/gitlab/gitlab-secrets.json
    fi
  fi
}

sync_gitlab_secrets() { 
  local default_value='DEFAULT'
  local secret_value='DEFAULT'
  local max_wait_time=1800  # 최대 대기 시간 (초)
  local wait_interval=10    # 체크 간격 (초)
  local elapsed_time=0

    if [ "$secret_value" == "$default_value" ]; then
    while [ ! -f "/etc/gitlab/gitlab-secrets.json" ] && [ $elapsed_time -lt $max_wait_time ]; do
      sleep $wait_interval
      elapsed_time=$((elapsed_time + wait_interval))
    done

    if [ -f "/etc/gitlab/gitlab-secrets.json" ]; then
      aws secretsmanager update-secret --secret-id "gitlab-secretjson-4b8db25c" --secret-string file:///etc/gitlab/gitlab-secrets.json
    fi
  fi
  
  
  install_log "sync_gitlab_secrets"
}

#-----------------------------------------------------------------------------------------------------------------------------------
# 라이센스 추가 
#-----------------------------------------------------------------------------------------------------------------------------------
apply_license() {
    local license_file_path="/etc/gitlab/gitlab-license"
  
  sudo gitlab-rails console -e production <<EOF
license_file = File.open('$license_file_path')
key = license_file.read.gsub("\r\n", "\n").gsub(/\n+$/, '') + "\n"
license = License.new(data: key)
license.save
puts License.current
EOF
    install_log "apply_license"
}

#-----------------------------------------------------------------------------------------------------------------------------------
# Main
#-----------------------------------------------------------------------------------------------------------------------------------
main() {
  check_os

  case "$operating_system" in
    "ubuntu")
      DEBIAN_FRONTEND=noninteractive
      export DEBIAN_FRONTEND 

      wait_until_other_services_up
      configure_gitlab_rb
      migrate_and_configure_db
      copy_ssh_keys 
      configure_gitlab_reload
      apply_license
      configure_geo
      sync_gitlab_secrets
      gitlab_status_report
      ;;
    *)
      echo "Unsupported operating system."
      exit 1
      ;;
  esac
}

main
--MIMEBOUNDARY--
