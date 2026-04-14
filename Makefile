.PHONY: test lint shellcheck actionlint

test:
	@command -v bats >/dev/null 2>&1 || { \
		echo "bats is not installed. Install it with: brew install bats-core"; \
		exit 1; \
	}
	bats tests/

lint: shellcheck actionlint

shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || { \
		echo "shellcheck is not installed. Install it with: brew install shellcheck"; \
		exit 1; \
	}
	shellcheck scripts/*.sh

actionlint:
	@command -v actionlint >/dev/null 2>&1 || { \
		echo "actionlint is not installed. Install it with: brew install actionlint"; \
		exit 1; \
	}
	actionlint
