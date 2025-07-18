# syntax=docker/dockerfile:1

### Dev Stage
FROM openmrs/openmrs-core:dev-amazoncorretto-17 AS dev
WORKDIR /openmrs_distro

ARG MVN_ARGS_SETTINGS="-s /usr/share/maven/ref/settings-docker.xml -U -P distro"
ARG MVN_ARGS="install"

RUN id

# Copy build files
COPY pom.xml ./
COPY distro ./distro/

# Build the distro, but only deploy from the amd64 build
#RUN --mount=type=secret,id=m2settings,target=/usr/share/maven/ref/settings-docker.xml if [[ "$MVN_ARGS" != "deploy" || "$(arch)" = "x86_64" ]]; then mvn $MVN_ARGS_SETTINGS $MVN_ARGS; else mvn $MVN_ARGS_SETTINGS install; fi
RUN mvn -U -P distro install || mvn install

RUN cp /openmrs_distro/distro/target/sdk-distro/web/openmrs_core/openmrs.war /openmrs/distribution/openmrs_core/

RUN cp /openmrs_distro/distro/target/sdk-distro/web/openmrs-distro.properties /openmrs/distribution/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_modules /openmrs/distribution/openmrs_modules/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_owas /openmrs/distribution/openmrs_owas/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_config /openmrs/distribution/openmrs_config/

# Clean up after copying needed artifacts
RUN mvn $MVN_ARGS_SETTINGS clean

### Run Stage
# Replace 'nightly' with the exact version of openmrs-core built for production (if available)
FROM openmrs/openmrs-core:nightly-amazoncorretto-17

# Do not copy the war if using the correct openmrs-core image version
COPY --from=dev /openmrs/distribution/openmrs_core/openmrs.war /openmrs/distribution/openmrs_core/

COPY --from=dev /openmrs/distribution/openmrs-distro.properties /openmrs/distribution/
COPY --from=dev /openmrs/distribution/openmrs_modules /openmrs/distribution/openmrs_modules
COPY --from=dev /openmrs/distribution/openmrs_owas /openmrs/distribution/openmrs_owas
COPY --from=dev  /openmrs/distribution/openmrs_config /openmrs/distribution/openmrs_config

# Copy WAR into the Tomcat webapps directory
RUN mkdir -p /usr/local/tomcat/webapps
COPY --from=dev /openmrs/distribution/openmrs_core/openmrs.war /usr/local/tomcat/webapps/openmrs.war

RUN id

# Optional: suppress permission warning
RUN mkdir -p /usr/local/tomcat/conf/Catalina/localhost

ENV DB_HOST=${DB_HOST}
ENV DB_PORT=${DB_PORT}
ENV DB_NAME=${DB_NAME}
ENV DB_USER=${DB_USER}
ENV DB_PASSWORD=${DB_PASSWORD}

CMD ["sh", "-c", "id && catalina.sh run"]

#CMD ["catalina.sh", "run"]

#CMD ["sh", "-c", "while ! echo > /dev/tcp/$DB_HOST/$DB_PORT; do echo waiting for database at $DB_HOST:$DB_PORT...; sleep 3; done; exec /start-openmrs.sh"]
#CMD ["sh", "-c", "until nc -z $DB_HOST $DB_PORT; do echo waiting for database...; sleep 3; done; exec /start-openmrs.sh"]
#CMD ["wait-for-it.sh", "${DB_HOST:-localhost}:${DB_PORT:-3306}", "--", "/start-openmrs.sh"]
