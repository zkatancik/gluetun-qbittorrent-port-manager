OWNER ?= zkatancik
IMAGE ?= gluetun-qbittorrent-port-manager
NAME  := $(OWNER)/$(IMAGE)
VERSION := $(shell cat version)
REGISTRY ?= index.docker.io

.PHONY: build login push

build: Dockerfile start.sh
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(NAME):$(VERSION) -t $(NAME):latest \
		--label "version=$(VERSION)" --load .

login: .secret
	@echo "Logging in to $(REGISTRY) as $(OWNER)"
	@if [ ! -s .secret ]; then echo "ERROR: .secret is missing or empty"; exit 1; fi
	@cat .secret | docker login $(REGISTRY) -u $(OWNER) --password-stdin

push: login Dockerfile start.sh version
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(NAME):$(VERSION) -t $(NAME):latest \
		--label "version=$(VERSION)" --push .
