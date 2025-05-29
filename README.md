# ICE_AWX_GITLAB

- ansible 통한 gitlab ha 배포를 위한 레포지토리

## Prerequsite

- minio 에서 아래 버킷 만들기 (만들때 versioning : `ON`)
  - gitlab-bucket
  - gitlab-ci-secure
  - gitlab-backup

- minio 에서 accesskey, secretkey 얻기

- 도메인 서버에 도메인 등록하기 (mygitlab.idtice.com)

### Gitlab Ansible 프로젝트

[ICE_AWX_Gitlab](https://github.com/iceTeamRepo/ICE_AWX_Gitlab.git)

## 배포

1. `haproxy`
   - playbook
     - install_gitlab_lb.yml
   - variables
     - hostname: haproxy

2. `consul`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: consul1, consul2, consul3
     - batch_size: 3

3. `psql`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: psql1, psql2
     - batch_size: 2

4. `pgbouncer`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: pgbouncer

5. `redis`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: redis1

4. `praefect_db`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: praefect_db

5. `praefect`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: praefect1

6. `gitaly`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: gitaly1

7. `sidekiq`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: sidekiq
     - minio_access_key: <minio access key>
     - minio_secret_key: <minio secret key>

8.  `rails`
    - playbook
      - install_gitlab_ha_rails.yml
    - variables
      - hostname: rails
      - minio_access_key: <minio access key>
      - minio_secret_key: <minio secret key>
      - patroni_leader_ip: <patroni leader ip>

9.  `prometheus`
    - playbook
      - install_gitlab_ha.yml
    - variables
      - hostname: prometheus

10. `exproxy`
    - playbook
      - install_gitlab_ex_lb.yml
    - variables
      - hostname: exproxy

## 확인

 
  ```bash
    # Consul
    $ sudo /opt/gitlab/embedded/bin/consul members

    # PSQL 확인
    $ sudo gitlab-ctl patroni members

  
    # praefect 확인 
    $ sudo GRPC_TRACE=all GRPC_VERBOSITY=DEBUG gitlab-rake gitlab:praefect:check
    $ sudo -u git /opt/gitlab/embedded/bin/praefect -config /var/opt/gitlab/praefect/config.toml sql-ping

    # gitaly 확인
    $ sudo gitlab-rake gitlab:gitaly:check 
    
    # rails 확인
    $ sudo gitlab-rake gitlab:check
  ```