.PHONY: build
build:
	hugo server -t etch

.PHONY: docs
docs:
	hugo -d docs
