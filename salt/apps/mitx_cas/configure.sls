include:
  - uwsgi.service

manage_mitx_cas_configuration_file:
  file.managed:
    - name: /etc/mitx-cas/cas.yml
    - contents: |
        {{ salt.pillar.get('mitx_cas:config')|yaml(False)|indent(8) }}
    - mode: '0644'
    - makedirs: True
    - onchanges_in:
      - service: uwsgi_service_running