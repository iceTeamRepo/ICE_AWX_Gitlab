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

- https://github.com/iceTeamRepo/ICE_AWX_Gitlab.git

## Ansible Tower 템플릿 생성

1. `haproxy`
   - playbook
     - install_lb.yml
   - variables
     - hostname: haproxy

1. `exproxy`
    - playbook
      - install_lb.yml
    - variables
      - hostname: exproxy

1. `consul`
   - playbook
     - install_gitlab.yml
   - variables
     - hostname: consul1, consul2, consul3
     - batch_size: 3

2. `psql`
   - playbook
     - install_gitlab.yml
   - variables
     - hostname: psql1, psql2

2. `redis`
   - playbook
     - install_gitlab.yml
   - variables
     - hostname: redis1

2. `praefect_db`
   - playbook
     - install_gitlab.yml
   - variables
     - hostname: praefect_db


3. `pgbouncer`
   - playbook
     - install_gitlab.yml
   - variables
     - hostname: pgbouncer


3. `praefect`
   - playbook
     - install_gitlab.yml
   - variables
     - hostname: praefect1

4. `gitaly`
   - playbook
     - install_gitlab.yml
   - variables
     - hostname: gitaly1

5.  `rails`
    - playbook
      - install_gitlab.yml
    - variables
      - hostname: rails1
      - minio_access_key: 0n6yJTUXGwLehtDLmvsg
      - minio_secret_key: EsHbGswvZuGz3DdN3TuJvBt1JQ0EK7OxZm4JsVmH


## 실행 순서

 1. `haproxy`, `exproxy`, `consul`
 2. `psql`, `redis`, `praefect_db`
 3. `pgbouncer`, `praefect`
 4. `gitaly`
 5. `sidekiq`
 6. `rails`
 

## 실행 후 수행
 
1. rails 노드의 /etc/gitlab/gitlab-secrets.json 값 복사
2. gitaly, praefect 노드에  /etc/gitlab/gitlab-secrets.json 로 붙여넣기
3. gitlay, praefect 노드 reconfigure
 

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

## Reference

- [Gitlab 아키텍처](https://docs.gitlab.com/administration/reference_architectures/#requirements)
- [Gitlab 설치](https://about.gitlab.com/install/#ubuntu)