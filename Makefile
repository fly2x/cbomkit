# extract cbomkit version tag from pom.xml
VERSION := $(shell curl -s https://api.github.com/repos/cbomkit/cbomkit/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
# set engine to use for build and compose, default to docker
ENGINE ?= docker
# Use explicit service sets because docker-compose/podman-compose profile support is inconsistent.
DEV_SERVICES := db
DEV_BACKEND_SERVICES := frontend db
DEV_FRONTEND_SERVICES := backend db
PRODUCTION_SERVICES := backend frontend db
VIEWER_SERVICES := frontend
EXT_COMPLIANCE_SERVICES := backend frontend db regulator opa
# build the backend
build-backend:
	./mvnw clean package
# build the container image for the backend
build-backend-image: build-backend
	$(ENGINE) build \
		-t cbomkit:${VERSION} \
		-f src/main/docker/Dockerfile.jvm \
		. \
		--load
# build the container image for the frontend
build-frontend-image:
	$(ENGINE) build \
		-t cbomkit-frontend:${VERSION} \
		-f frontend/docker/Dockerfile \
		./frontend \
		--load
# run the dev setup using docker/podman compose
dev:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit $(ENGINE)-compose up -d $(DEV_SERVICES)
dev-backend:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit $(ENGINE)-compose up -d $(DEV_BACKEND_SERVICES)
dev-frontend:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit $(ENGINE)-compose up $(DEV_FRONTEND_SERVICES)
# run the prod setup using $(ENGINE) compose
production:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit $(ENGINE)-compose up $(PRODUCTION_SERVICES)
edge:
	$(ENGINE) pull ghcr.io/cbomkit/cbomkit:edge
	$(ENGINE) pull ghcr.io/cbomkit/cbomkit-frontend:edge
	env CBOMKIT_VERSION=edge CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit $(ENGINE)-compose up $(PRODUCTION_SERVICES)
coeus:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=true $(ENGINE)-compose up $(VIEWER_SERVICES)
ext-compliance:
	env CBOMKIT_VERSION=${VERSION} CBOMKIT_VIEWER=false POSTGRESQL_AUTH_USERNAME=cbomkit POSTGRESQL_AUTH_PASSWORD=cbomkit $(ENGINE)-compose up $(EXT_COMPLIANCE_SERVICES)

deploy:
	helm install cbomkit \
		--set common.clusterDomain=openshift-cluster-d465a2b8669424cc1f37658bec09acda-0000.eu-de.containers.appdomain.cloud \
		--set cbomkit.tag=${VERSION} \
		--set frontend.tag=${VERSION} \
		--set postgresql.auth.username=cbomkit \
		--set postgresql.auth.password=cbomkit \
		./chart

undeploy:
	helm uninstall cbomkit
