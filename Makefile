all: format lint
	@echo done

format:
	@echo '--- format ---'
	@gdformat src/**/*.gd

lint:
	@echo '--- lint ---'
	@output=`gdlint src/**/*.gd 2>&1 \
		| rg -v "(\(trailing-whitespace\)|\(function-preload-variable-name\))" \
		| head -n -1`
