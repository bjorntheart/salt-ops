{% set VPC_NAME = salt.environ.get('VPC_NAME', 'MITx QA') %}
{% set VPC_RESOURCE_SUFFIX = salt.environ.get(
    'VPC_RESOURCE_SUFFIX',
    VPC_NAME.lower().replace(' ', '-')) %}
{% set ENVIRONMENT = salt.environ.get(
    'ENVIRONMENT',
    VPC_NAME.lower().replace(' ', '-')) %}
{% set BUSINESS_UNIT = salt.environ.get('BUSINESS_UNIT', 'residential') %}
{% set VPC_RESOURCE_SUFFIX_UNDERSCORE = VPC_RESOURCE_SUFFIX.replace('-', '_') %}
{% set app_name = salt.environ.get('APP_NAME', 'edx') %}
{% set env_settings = salt.pillar.get('environments:{}'.format(ENVIRONMENT)) %}
{% set network_prefix = env_settings.network_prefix %}
{% set cidr_block_public_subnet_1 = '{}.1.0/24'.format(network_prefix) %}
{% set cidr_block_public_subnet_2 = '{}.2.0/24'.format(network_prefix) %}
{% set cidr_block_public_subnet_3 = '{}.3.0/24'.format(network_prefix) %}
{% set cidr_ip = '{}.0.0/22'.format(network_prefix) %}
{% set cidr_block = '{}.0.0/16'.format(network_prefix) %}

create_{{ app_name }}_security_group_in_{{ VPC_NAME }}:
  boto_secgroup.present:
    - name: {{ app_name }}-{{ VPC_RESOURCE_SUFFIX }}
    - description: Access rules for EdX instances
    - vpc_name: {{ VPC_NAME }}
    - rules:
        - ip_protocol: tcp
          from_port: 80
          to_port: 80
          cidr_ip: 0.0.0.0/0
        - ip_protocol: tcp
          from_port: 443
          to_port: 443
          cidr_ip: 0.0.0.0/0
        - ip_protocol: tcp
          from_port: 22
          to_port: 22
          cidr_ip:
            - 10.0.0.0/22 # Operations VPC: Necessary for salt provisioning
            - {{ cidr_ip }}
    - require:
        - boto_vpc: create_{{ VPC_RESOURCE_SUFFIX_UNDERSCORE }}_vpc
    - tags:
        Name: {{ app_name }}-{{ VPC_RESOURCE_SUFFIX }}
        business_unit: {{ BUSINESS_UNIT }}
