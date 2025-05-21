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

reconfigure_gitlab() {
  local MAX_RETRIES=$1
  local RETRY_COUNT=0

  while [ $RETRY_COUNT -lt $MAX_RETRIES ]
  do
      gitlab-ctl reconfigure 2>&1 | sudo tee /tmp/reconfigure_output.log
      if ! grep -q "ERROR" reconfigure_output.log; then
          return 0 
      fi

      install_log "오류가 발생했습니다. 다시 시도합니다..."
      
      RETRY_COUNT=$((RETRY_COUNT + 1))

      # 최대 재시도 횟수를 초과했을 경우 종료
      if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
          install_log "최대 재시도 횟수에 도달했습니다. 설정을 완료할 수 없습니다."
          return 1
      fi

      sleep 10
  done
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
# generate_pg_password_md5 :  pgbouncer 구성에 사용할 password hash generator
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
# configure_pgbouncer : pgbouncer 구성
#-----------------------------------------------------------------------------------------------------------------------------------
configure_pgbouncer(){  

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

roles(['pgbouncer_role'])

pgbouncer['admin_users'] = %w(pgbouncer gitlab-consul)
pgbouncer['users'] = {
   'gitlab-consul': {
      password: '$consul_password_hash'
   },
   'pgbouncer': {
      password: '$pgbouncer_password_hash'
   }
}

consul['enable'] = true
consul['watchers'] = %w(postgresql)
consul['monitoring_service_discovery'] =  true
consul['configuration'] = {
  retry_join: %w(10.0.10.120 10.0.11.120 10.0.12.120),
}

node_exporter['listen_address'] = '0.0.0.0:9100'
pgbouncer_exporter['listen_address'] = '0.0.0.0:9188'

gitlab_rails['initial_license_file'] = '/etc/gitlab/gitlab-license'

EOF

  install_log "configure_pgbouncer"
}


#-----------------------------------------------------------------------------------------------------------------------------------
# configure_gitlab_reload : pgbouncer  재시작
#-----------------------------------------------------------------------------------------------------------------------------------
configure_gitlab_reload() {
  reconfigure_gitlab 5
  sudo gitlab-ctl restart
  install_log "configure_gitlab_reload"
}

#-----------------------------------------------------------------------------------------------------------------------------------
# create_pgpass_for_consul_reload : Consul이 PgBouncer를 리로드할 수 있도록 .pgpass 파일을 생성하는 작업
#-----------------------------------------------------------------------------------------------------------------------------------
create_pgpass_for_consul_reload() { 
  local password="pgbouncerpassword"
  echo -e "$password\n$password" | sudo gitlab-ctl write-pgpass --host 127.0.0.1 --database pgbouncer --user pgbouncer --hostuser gitlab-consul
  gitlab-ctl hup pgbouncer

  reconfigure_gitlab 5
  sudo gitlab-ctl restart

  install_log "create_pgpass_for_consul_reload"
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
      configure_pgbouncer
      configure_gitlab_reload
      create_pgpass_for_consul_reload
      ;;
    *)
      echo "Unsupported operating system."
      exit 1
      ;;
  esac
}

main
 
--MIMEBOUNDARY--
