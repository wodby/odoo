-include env_make

# Odoo's series and the date of Odoo's build of it: 20.0.20261102 is the official image tag 20.0-20261102.
ODOO_VER ?= 20.0.20261102
ODOO_VER_MINOR := $(basename $(ODOO_VER))
ODOO_RELEASE := $(subst .,,$(suffix $(ODOO_VER)))
ODOO_VER_MAJOR := $(basename $(ODOO_VER_MINOR))

TAG ?= $(ODOO_VER_MAJOR)

REPO = wodby/odoo
NAME = odoo-$(ODOO_VER_MAJOR)

IMAGETOOLS_TAG ?= $(TAG)

ifneq ($(ARCH),)
	override TAG := $(TAG)-$(ARCH)
endif

.PHONY: build test push shell run clean buildx-imagetools-create

# Resolve the same pinned base image for every local and CI build target.
include base-images.mk
BASE_IMAGE_TAG = $(ODOO_VER_MINOR)-$(ODOO_RELEASE)

default: build

build:
	docker build --build-arg BASE_IMAGE="$(BASE_IMAGE)" -t $(REPO):$(TAG) ./

test:
	cd ./tests && IMAGE=$(REPO):$(TAG) NAME=$(NAME) ODOO_VER=$(ODOO_VER_MINOR) ./run.sh

push:
	docker push $(REPO):$(TAG)

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
				$(REPO):$(TAG)-amd64 \
				$(REPO):$(TAG)-arm64

shell:
	docker run --rm --name $(NAME) -i -t $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) /bin/bash

run:
	docker run --rm --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) $(CMD)

clean:
	-docker rm -f $(NAME)
