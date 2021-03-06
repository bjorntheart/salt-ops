{% set ENVIRONMENT = salt.grains.get('environment') %}
{% set env_settings = salt.cp.get_file_str("salt://environment_settings.yml")|load_yaml %}
{% set env_data = env_settings.environments[ENVIRONMENT] %}

consul:
  extra_configs:
    defaults:
      recursors:
        - {{ env_settings.environments[ENVIRONMENT].network_prefix }}.0.2
        - 8.8.8.8
    {% if 'consul_server' in salt.grains.get('roles', []) %}
    {% set mysql_endpoint = salt.boto_rds.get_endpoint('{env}-rds-mysql'.format(env=ENVIRONMENT)) %}
    hosted_services:
      services:
        - name: mysql
          port: {{ mysql_endpoint.split(':')[1] }}
          address: {{ mysql_endpoint.split(':')[0] }}
          check:
            tcp: '{{ mysql_endpoint }}'
            interval: 10s
    {% endif %}
