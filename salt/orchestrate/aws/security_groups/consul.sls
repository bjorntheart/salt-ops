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

create_consul_security_group_in_{{ VPC_NAME }}:
  boto_secgroup.present:
    - name: consul-{{ VPC_RESOURCE_SUFFIX }}
    - description: Access rules for Consul cluster in {{ VPC_NAME }} stack
    - vpc_name: {{ VPC_NAME }}
    - rules:
        - ip_protocol: tcp
          from_port: 8500
          to_port: 8500
          cidr_ip:
            - {{ cidr_ip }}
          {# HTTP access #}
        - ip_protocol: udp
          from_port: 8500
          to_port: 8500
          cidr_ip:
            - {{ cidr_ip }}
          {# HTTP access #}
        - ip_protocol: tcp
          from_port: 8600
          to_port: 8600
          cidr_ip:
            - {{ cidr_ip }}
          {# DNS access #}
        - ip_protocol: udp
          from_port: 8600
          to_port: 8600
          cidr_ip:
            - {{ cidr_ip }}
          {# DNS access #}
        - ip_protocol: tcp
          from_port: 8300
          to_port: 8301
          cidr_ip:
            - {{ cidr_ip }}
          {# LAN gossip protocol #}
        - ip_protocol: udp
          from_port: 8300
          to_port: 8301
          cidr_ip:
            - {{ cidr_ip }}
          {# LAN gossip protocol #}
        - ip_protocol: tcp
          from_port: 8300
          to_port: 8302
          cidr_ip:
            - 10.0.0.0/22
            - {{ cidr_ip }}
          {# WAN cluster interface #}
    - require:
        - boto_vpc: create_{{ VPC_RESOURCE_SUFFIX_UNDERSCORE }}_vpc
    - tags:
        Name: consul-{{ VPC_RESOURCE_SUFFIX }}
        business_unit: {{ BUSINESS_UNIT }}

create_consul_agent_security_group_in_{{ VPC_NAME }}:
  boto_secgroup.present:
    - name: consul-agent-{{ VPC_RESOURCE_SUFFIX }}
    - description: Access rules for Consul agent in {{ VPC_NAME }} stack
    - vpc_name: {{ VPC_NAME }}
    - rules:
        - ip_protocol: tcp
          from_port: 8301
          to_port: 8301
          source_group_name: consul-agent-{{ VPC_RESOURCE_SUFFIX }}
        - ip_protocol: udp
          from_port: 8301
          to_port: 8301
          source_group_name: consul-agent-{{ VPC_RESOURCE_SUFFIX }}
        - ip_protocol: tcp
          from_port: 8301
          to_port: 8301
          source_group_name: consul-{{ VPC_RESOURCE_SUFFIX }}
        - ip_protocol: udp
          from_port: 8301
          to_port: 8301
          source_group_name: consul-{{ VPC_RESOURCE_SUFFIX }}
    - require:
        - boto_vpc: create_{{ VPC_RESOURCE_SUFFIX_UNDERSCORE }}_vpc
        - boto_secgroup: create_mitx_consul_security_group
    - tags:
        Name: consul-agent-{{ VPC_RESOURCE_SUFFIX }}
        business_unit: {{ BUSINESS_UNIT }}
