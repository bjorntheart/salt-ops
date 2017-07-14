{% set ENVIRONMENT = salt.environ.get('ENVIRONMENT', 'mitx-rp') %}
{% set VPC_NAME = salt.environ.get('VPC_NAME', 'Dogwood RP') %}
{% set VPC_RESOURCE_SUFFIX = salt.environ.get('VPC_RESOURCE_SUFFIX',
                                              VPC_NAME.lower() | replace(' ', '-')) %}
{% set subnet_ids = [] %}
{% for subnet in salt.boto_vpc.describe_subnets(subnet_names=[
    'public1-{}'.format(VPC_RESOURCE_SUFFIX), 'public2-{}'.format(VPC_RESOURCE_SUFFIX), 'public3-{}'.format(VPC_RESOURCE_SUFFIX)])['subnets'] %}
{% do subnet_ids.append('{0}'.format(subnet['id'])) %}
{% endfor %}
{% set slack_api_token = salt.vault.read('secret-operations/global/slack/slack_api_token').data.value %}
{% set instance_name = 'backup-{}'.format(ENVIRONMENT) %}

ensure_backup_bucket_exists:
  boto_s3_bucket.present:
    - Bucket: odl-operations-backups
    - Versioning:
        Status: Enabled
    - region: us-east-1

ensure_instance_profile_exists_for_backups:
  boto_iam_role.present:
    - name: backups-instance-role
    - delete_policies: False
    - policies:
        operations-backups-policy:
          Statement:
            - Action:
                - s3:*
              Effect: Allow
              Resource:
                - arn:aws:s3:::odl-operations-backups
                - arn:aws:s3:::odl-operations-backups/*
    - require:
        - boto_s3_bucket: ensure_backup_bucket_exists

load_backup_host_cloud_profile:
  file.managed:
    - name: /etc/salt/cloud.profiles.d/backup_host.conf
    - source: salt://orchestrate/aws/cloud_profiles/backup_host.conf
    - template: jinja

deploy_backup_instance_to_{{ ENVIRONMENT }}:
  salt.function:
    - name: cloud.profile
    - tgt: 'roles:master'
    - tgt_type: grain
    - arg:
        - backup_host
        - backup-{{ ENVIRONMENT }}
    - kwarg:
        vm_overrides:
          grains:
            environment: {{ ENVIRONMENT }}
          network_interfaces:
            - DeviceIndex: 0
              AssociatePublicIpAddress: True
              {# Chose 2nd subnet because we want the instance to be in the same AZ as backup volume. #}
              SubnetId: {{ subnet_ids[0] }}
              SecurityGroupId:
                - {{ salt.boto_secgroup.get_group_id(
                     'salt_master-{}'.format(VPC_RESOURCE_SUFFIX), vpc_name=VPC_NAME) }}
                - {{ salt.boto_secgroup.get_group_id(
                     'edx-{}'.format(VPC_RESOURCE_SUFFIX), vpc_name=VPC_NAME) }}
                - {{ salt.boto_secgroup.get_group_id(
                     'consul-agent-{}'.format(ENVIRONMENT), vpc_name=VPC_NAME) }}
          block_device_mappings:
            - DeviceName: xvda
              Ebs.VolumeSize: 8
              Ebs.VolumeType: gp2
            - DeviceName: /dev/xvdb
              Ebs.VolumeSize: 400
              Ebs.VolumeType: gp2
          enable_term_protect: True
    - require:
        - file: load_backup_host_cloud_profile
        - boto_iam_role: ensure_instance_profile_exists_for_backups

format_and_mount_backup_drive:
  salt.state:
    - tgt: 'G@roles:backups and G@environment:{{ ENVIRONMENT }}'
    - tgt_type: compound
    - sls:
        - backups.mount_drive
    - require:
        - salt: deploy_backup_instance_to_{{ ENVIRONMENT }}

{% if salt['cloud.get_instance'](instance_name) %}
{% if salt['cloud.get_instance'](instance_name)['state'] != 'running' %}
start_backup_instance_in_{{ ENVIRONMENT }}:
  salt.function:
    - name: cloud.action
    - tgt: 'roles:master'
    - tgt_type: grain
    - arg:
        - start
    - kwarg:
        instance: backup-{{ ENVIRONMENT }}
    - require:
        - salt: deploy_backup_instance_to_{{ ENVIRONMENT }}
    - require_in:
        - salt: execute_enabled_backup_scripts
{% endif %}
{% endif %}

execute_enabled_backup_scripts:
  salt.state:
    - tgt: 'G@roles:backups and G@environment:{{ ENVIRONMENT }}'
    - tgt_type: compound
    - sls:
        - consul
        - consul.dns_proxy
        - backups.backup
    - require:
        - salt: deploy_backup_instance_to_{{ ENVIRONMENT }}

stop_backup_instance_in_{{ ENVIRONMENT }}:
  salt.function:
    - name: cloud.action
    - tgt: 'roles:master'
    - tgt_type: grain
    - arg:
        - stop
    - kwarg:
        instance: backup-{{ ENVIRONMENT }}
    - require:
        - salt: execute_enabled_backup_scripts

alert_devops_channel_on_failure:
  slack.post_message:
    - channel: '#devops'
    - from_name: saltbot
    - message: 'The scheduled backup for edX RP has failed.'
    - api_key: {{ slack_api_token }}
    - onfail:
        - salt: execute_enabled_backup_scripts

alert_devops_channel_on_success:
  slack.post_message:
    - channel: '#devops'
    - from_name: saltbot
    - message: 'The scheduled backup for edX RP has succeeded.'
    - api_key: {{ slack_api_token }}
    - require:
        - salt: execute_enabled_backup_scripts
        - salt: stop_backup_instance_in_{{ ENVIRONMENT }}
