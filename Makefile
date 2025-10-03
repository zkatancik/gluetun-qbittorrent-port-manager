SHELL := /bin/sh
OWNER ?= zkatancik
IMAGE ?= gluetun-qbittorrent-port-manager
NAME  := $(OWNER)/$(IMAGE)
VERSION := $(shell cat version)
REGISTRY ?= index.docker.io

.PHONY: build login push

login: .secret
	@echo "Logging in as $(OWNER)"
	@[ -f .secret ] && [ -s .secret ] || { echo "ERROR: .secret is missing or empty"; exit 1; }
	@tr -d '\r\n' < .secret | docker login -u $(OWNER) --password-stdin

build: Dockerfile start.sh
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(NAME):$(VERSION) -t $(NAME):latest \
		--label "version=$(VERSION)" --load .

push: login Dockerfile start.sh version
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(NAME):$(VERSION) -t $(NAME):latest \
		--label "version=$(VERSION)" --push .
