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

#! /bin/bash 

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
  install_log "check_os"
}

#-----------------------------------------------------------------------------------------------------------------------------------
# generate_pg_password_md5 :  psql 구성에 사용할 password hash generator
#-----------------------------------------------------------------------------------------------------------------------------------
generate_pg_password_md5() {
  local service=$1
  local password=$2

  case "$service" in
    gitlab|pgbouncer|gitlab_replicator|gitlab-consul)
      echo -e "$password\n$password" | sudo gitlab-ctl pg-password-md5 "$service"
      ;;
    *)
      echo "Usage: generate_pg_password_md5 {gitlab|pgbouncer|gitlab_replicator|gitlab-consul} <password>"
      return 1
      ;;
  esac
}

#-----------------------------------------------------------------------------------------------------------------------------------
# configure_psql : psql 구성
#-----------------------------------------------------------------------------------------------------------------------------------
configure_psql(){  

  pgbouncer_password_hash=$(generate_pg_password_md5 "pgbouncer" "pgbouncerpassword")
  postgresql_password_hash=$(generate_pg_password_md5 "gitlab" "psqlpassword")
  postgresql_replication_password_hash=$(generate_pg_password_md5 "gitlab_replicator" "psqlreplicatorpassword")
  consul_password_hash=$(generate_pg_password_md5 "gitlab-consul" "consulpassword")

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

  rm -rf /etc/gitlab/gitlab.rb

  cat <<-EOF >> /etc/gitlab/gitlab.rb

#gitlab_rails['time_zone'] = 'Asia/Seoul'

roles(['patroni_role', 'pgbouncer_role'])

postgresql['listen_address'] = '0.0.0.0'


patroni['postgresql']['max_replication_slots'] = 4
patroni['postgresql']['max_wal_senders'] = 5
gitlab_rails['auto_migrate'] = false

postgresql['pgbouncer_user_password'] = '$pgbouncer_password_hash'
postgresql['sql_replication_user'] = "gitlab_replicator"
postgresql['sql_replication_password'] = '$postgresql_replication_password_hash'
postgresql['sql_user_password'] = '$postgresql_password_hash'

postgresql['username'] = "gitlab-psql"
postgresql['group'] = "gitlab-psql"

patroni['username'] = 'patroni'
patroni['password'] = 'patronipassword'

patroni['allowlist'] = %w[
  127.0.0.1/32
  10.0.10.130/32 10.0.11.130/32
]

postgresql['trust_auth_cidr_addresses'] = %w(10.0.0.0/16 127.0.0.1/32)

pgbouncer['databases'] = {
   gitlabhq_production: {
      host: "127.0.0.1",
      user: "pgbouncer",
      password: '$pgbouncer_password_hash'
   }
}

consul['enable'] = true
consul['services'] = %w(postgresql)
consul['monitoring_service_discovery'] =  true
consul['configuration'] = {
  retry_join: %w( 10.0.10.120 10.0.11.120 10.0.12.120 ),
}

node_exporter['listen_address'] = '0.0.0.0:9100'
postgres_exporter['listen_address'] = '0.0.0.0:9187' 


gitlab_rails['initial_license_file'] = '/etc/gitlab/gitlab-license'

EOF

  install_log "configure_psql"
}

#-----------------------------------------------------------------------------------------------------------------------------------
# configure_gitlab_reload : psql  재시작
#-----------------------------------------------------------------------------------------------------------------------------------
configure_gitlab_reload() {
  sudo gitlab-ctl reconfigure
  sudo gitlab-ctl restart
  install_log "configure_gitlab_reload"
}

#-----------------------------------------------------------------------------------------------------------------------------------
# sync_gitlab_secrets : gitlab-secrets.json 파일 일치시키기
#-----------------------------------------------------------------------------------------------------------------------------------
sync_gitlab_secrets() {
   install_log "sync_gitlab_secrets"
}

#-----------------------------------------------------------------------------------------------------------------------------------
# check_patroni_members : patroni 상태 체크
#-----------------------------------------------------------------------------------------------------------------------------------
check_patroni_members() {
  wait_interval=30   # 30초마다 상태를 점검
  max_retries=10     # 최대 10번 시도
  attempt=1          # 시도 횟수

  while [ "$attempt" -le "$max_retries" ]; do
    patroni_output=$(gitlab-ctl patroni members)
    host_count=$(echo "$patroni_output" | awk 'NR>2 {print $3}' | grep -v '^$' | wc -l)

    # 호스트 수 확인
    if [ "$host_count" -eq 2 ]; then
      install_log "Patroni is configured correctly. All 2 nodes are alive."

      # 결과를 /etc/gitlab/patroni_check 파일에 저장
      echo "All 3 Patroni nodes are alive at $(date)" | sudo tee /etc/gitlab/patroni_check > /dev/null
      echo "$patroni_output" | sudo tee -a /etc/gitlab/patroni_check > /dev/null
      
      # 결과를 AWS Secrets Manager에 저장
      aws secretsmanager update-secret --secret-id "gitlab-patroni-96bef895" --secret-string file:///etc/gitlab/patroni_check

      # Leader IP를 추출 및 AWS Secrets Manager에 저장
      leader_ip=$(echo "$patroni_output" | grep "Leader" | awk '{print $4}')
      aws secretsmanager update-secret --secret-id "gitlab-patroni_leader_ip-989bd4bd" --secret-string "$leader_ip"
      
      break
    else
      install_log "Not all nodes are alive. Waiting for 30 seconds before retrying... (Attempt $attempt/$max_retries)"
      attempt=$((attempt + 1))
      sudo gitlab-ctl reconfigure
      sudo gitlab-ctl restart
      sleep $wait_interval
    fi
  done

  if [ "$attempt" -gt "$max_retries" ]; then
    install_log "Failed to verify all 3 Patroni nodes after $max_retries attempts."
  fi

  install_log "check_patroni_members"
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
      configure_psql
      configure_gitlab_reload
      check_patroni_members
      #sync_gitlab_secrets
      ;;
    *)
      echo "Unsupported operating system."
      exit 1
      ;;
  esac
}

main
 
--MIMEBOUNDARY--
