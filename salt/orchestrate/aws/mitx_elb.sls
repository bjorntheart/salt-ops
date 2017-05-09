{% from "orchestrate/aws_env_macro.jinja" import VPC_NAME, VPC_RESOURCE_SUFFIX,
 ENVIRONMENT, PURPOSE_PREFIX, subnet_ids with context %}
{% set env_settings = salt.pillar.get('environments:{}'.format(ENVIRONMENT)) %}

{% set security_groups = salt.pillar.get('edx:lb_security_groups', ['default', 'edx-{env}'.format(env=ENVIRONMENT)]) %}

{% for edx_type in ['draft', 'live'] %}
{% set purpose_name = '{prefix}-{app}'.format(
    prefix=PURPOSE_PREFIX, app=edx_type) %}
{% set purpose = env_settings.purposes[purpose_name] %}
{% set elb_name = 'edx-{purpose}-{env}'.format(
   purpose=purpose_name, env=ENVIRONMENT)[:32].strip('-') %}
create_elb_for_edx_{{ purpose_name }}:
  boto_elb.present:
    - name: {{ elb_name }}
    - listeners:
        - elb_port: 443
          instance_port: 443
          elb_protocol: HTTPS
          instance_protocol: HTTPS
          certificate: arn:aws:iam::610119931565:server-certificate/mitx-wildcard-cert
          policies:
            - {{ elb_name }}-sticky-cookie-policy
        - elb_port: 80
          instance_port: 80
          elb_protocol: HTTP
          instance_protocol: HTTP
          policies:
            - {{ elb_name }}-sticky-cookie-policy
    - attributes:
        cross_zone_load_balancing:
          enabled: True
        connection_draining:
          enabled: True
          timeout: 300
    - cnames:
        {% for domain_key, domain in purpose.domains.items()  %}
        {% if (edx_type == 'live' and domain_key in ['lms', 'gitreload'])
           or edx_type == 'draft' %}
        - name: {{ domain }}.
          zone: mitx.mit.edu.
          ttl: 60
        {% endif %}
        {% endfor %}
    - health_check:
        target: 'HTTPS:443/heartbeat'
    - subnets: {{ subnet_ids }}
    - security_groups: {{ security_groups }}
    - policies:
        - policy_name: {{ elb_name }}-sticky-cookie-policy
          policy_type: LBCookieStickinessPolicyType
          policy: {}

register_edx_{{ purpose_name }}_nodes_with_elb:
  boto_elb.register_instances:
    - name: {{ elb_name }}
    - instances:
        {% for instance_num in range(purpose.num_instances.edx) %}
        - {{ salt.boto_ec2.get_id('edx-{env}-{t}-{num}'.format(
            env=ENVIRONMENT, t=purpose_name, num=instance_num)) }}
        {% endfor %}
    - require:
        - boto_elb: create_elb_for_edx_{{ purpose_name }}
{% endfor %}