# ICE_AWX_GITLAB

- ansible 통한 gitlab ha 배포를 위한 레포지토리

## Prerequsite

- minio 에서 아래 버킷 만들기 (만들때 versioning : `ON`)
  - gitlab-bucket
  - gitlab-ci-secure
  - gitlab-backup

- minio 에서 accesskey, secretkey 얻기

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

3. `psql`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: psql1, psql2

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

6. `praefect_db`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: praefect_db

7. `praefect`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: praefect1

8. `gitaly`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: gitaly1

9. `sidekiq`
   - playbook
     - install_gitlab_ha.yml
   - variables
     - hostname: sidekiq
     - minio_access_key: <minio access key>
     - minio_secret_key: <minio secret key>

10. `rails`
    - playbook
      - install_gitlab_ha_rails.yml
    - variables
      - hostname: rails
      - minio_access_key: <minio access key>
      - minio_secret_key: <minio secret key>
      - patroni_leader_ip: <patroni leader ip>

11. `prometheus`
    - playbook
      - install_gitlab_ha.yml
    - variables
      - hostname: prometheus

12. `exproxy`
    - playbook
      - install_gitlab_ex_lb.yml
    - variables
      - hostname: exproxy