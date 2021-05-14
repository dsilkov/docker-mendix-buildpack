# Dockerfile to create a Mendix Docker image based on either the source code or
# Mendix Deployment Archive (aka mda file)
#
# Author: Mendix Digital Ecosystems, digitalecosystems@mendix.com
# Version: 2.0.0
#ARG ROOTFS_IMAGE=mxclyde/rootfs:bionic

#FROM ${ROOTFS_IMAGE}
FROM mxclyde/rootfs:bionic
LABEL Author="Mendix Digital Ecosystems"
LABEL maintainer="digitalecosystems@mendix.com"

# Build-time variables
ARG BUILD_PATH=project
ARG DD_API_KEY
# CF buildpack version
ARG CF_BUILDPACK=appInsightsAgent1
ARG APPMETRICS_AAI
ARG APPMETRICS_TARGET
ARG APPMETRICS_PROMETHEUS
ARG APPMETRICS_GRAYLOG
ARG BUILDPACK_XTRACE=true

# Each comment corresponds to the script line:
# 1. Install libpng12 backported from Xenial (required by Mono)
# 2. Create all directories needed by scripts
# 3. Create all directories needed by CF buildpack
# 4. Create symlink for java prefs used by CF buildpack
# 5. Download CF buildpack
RUN wget https://mxblobstore.azureedge.net/mxblobstore/libpng12-0_1.2.54-1ubuntu1.1_amd64.deb &&\
   dpkg -i libpng12-0_1.2.54-1ubuntu1.1_amd64.deb &&\
   mkdir -p buildpack build cache appinsights\
   "/.java/.userPrefs/com/mendix/core" "/root/.java/.userPrefs/com/mendix/core" &&\
   ln -s "/.java/.userPrefs/com/mendix/core/prefs.xml" "/root/.java/.userPrefs/com/mendix/core/prefs.xml" &&\
   echo "CF Buildpack version ${CF_BUILDPACK}" &&\
   wget -qO- https://github.com/dsilkov/cf-mendix-buildpack/archive/${CF_BUILDPACK}.tar.gz | tar xvz -C buildpack --strip-components 1 &&\
   wget https://devtools.cpggpc.ca/nexus/repository/test-repo/applicationinsights-agent-3.1.0.jar -P appinsights &&\
   wget https://devtools.cpggpc.ca/nexus/repository/test-repo/applicationinsights.json -P appinsights &&\
   pwd &&\
   ls &&\
   cp -r appinsights build 

# copy applicationinsights-agent-3.0.2.jar to 
#COPY appinsights build
# Copy python scripts which execute the buildpack (exporting the VCAP variables)
COPY scripts/compilation /buildpack
# Copy project model/sources
COPY $BUILD_PATH build

# Add the buildpack modules
ENV PYTHONPATH "/buildpack/lib/"

# Add ENV various for proxy of cdn
ENV BLOBSTORE=https://devtools.cpggpc.ca/nexus/repository/mendix-cdn-raw-proxy/

# Each comment corresponds to the script line:
# 1. Call compilation script
# 2. Remove temporary folders
# 3. Create mendix user with home directory at /root
# 4. Change ownership of /build /buildpack /.java /root to mendix
WORKDIR /buildpack
RUN "/buildpack/compilation" /build /cache &&\
    rm -fr /cache /tmp/javasdk /tmp/opt &&\
    useradd -r -U -u 999 -d /root mendix &&\
    chown -R mendix /buildpack /build /.java /root

# Copy start scripts
#COPY --chown=mendix:mendix scripts/startup /build
COPY scripts/startup /build
RUN chown mendix /build/startup
#COPY --chown=mendix:mendix scripts/vcap_application.json /build
COPY scripts/vcap_application.json /build
RUN chown mendix /build/vcap_application.json
WORKDIR /build

USER 999

# Expose nginx port
ENV PORT 8080
EXPOSE $PORT

ENTRYPOINT ["/build/startup","/buildpack/start.py"]
