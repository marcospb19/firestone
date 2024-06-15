all: format lint
	@echo done

format:
	@echo '--- format ---'
	@gdformat **/*.gd

lint:
	@echo '--- lint ---'
	@output=`gdlint **/*.gd 2>&1 \
		| rg -v "(\(trailing-whitespace\)|\(function-preload-variable-name\))" \
		| head -n -1`
