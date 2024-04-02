fmt:
	black . $(ARGS)

install:
	pip3 install --user -r requirements.txt

install-dev:
	pip3 install --user -r requirements_dev.txt

lint:
	pylint decrypt.py

test:
	python -m pytest -s -vv .

.PHONY: \
	fmt \
	install	\
	install-dev	\
	lint \
	test