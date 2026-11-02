# Build: docker build -t hop-etl:latest -f docker/Dockerfile .
# Run:   docker compose -f docker/compose.yaml up
FROM apache/hop:2.20.0

# project lives in the image so it is reproducible; override with a bind mount in dev
COPY . /opt/hop/projects/etl

ENV HOP_PROJECT_NAME=etl
ENV HOP_PROJECT_HOME=/opt/hop/projects/etl
ENV HOP_CONFIG_FOLDER=/opt/hop/.hop/config
ENV HOP_AUDIT_FOLDER=/opt/hop/.hop/audit
ENV HOP_IMPORT_ENVIRONMENT_VARIABLES=Y

# Google Drive OAuth token + Supabase secrets are mounted at runtime, never baked in
VOLUME ["/opt/hop/.hop", "/opt/hop/projects/etl/.env"]

WORKDIR /opt/hop
ENTRYPOINT ["/opt/hop/hop-run.sh"]
CMD ["-j", "etl", "-f", "/opt/hop/projects/etl/pipelines/01_check_drive.hpl", "-r", "local", "-l", "BASIC"]