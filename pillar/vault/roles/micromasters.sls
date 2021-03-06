vault:
  roles:
    micromasters-app:
      backend: postgresql-micromasters
      name: app
      options:
        {% raw %}
        sql: >-
          CREATE USER "{{name}}" WITH PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
          GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "{{name}}";
          GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "{{name}}";
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO "{{name}}";
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO "{{name}}";
        {% endraw %}
    micromasters-readonly:
      backend: postgresql-micromasters
      name: readonly
      options:
        {% raw %}
        sql: >-
          CREATE USER "{{name}}" WITH PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
          GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";
          GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO "{{name}}";
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO "{{name}}";
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO "{{name}}";
        {% endraw %}
