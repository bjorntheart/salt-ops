{% set redash_env = salt.pillar.get('django:environment') %}

migrate_redash_database:
  cmd.run:
    - name: /opt/redash/bin/run ./manage.py db upgrade
    - cwd: /opt/redash
    - runas: redash
    - env: {{ redash_env }}
    - require:
        - archive: deploy_application_source_to_destination
        - pip: install_python_requirements
        - pip: install_python_requirements_for_all_datasources
