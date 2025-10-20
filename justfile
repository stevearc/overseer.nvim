default:
  just --list

all: test

# variadic arguments
test *names:
  ./run_tests.sh {{names}}

# Private -- omitted from just --list
_private-task:
  echo "Private task"

doc:
	venv/bin/python scripts/main.py generate

lint:
  python .github/main.py lint
  stylua --check .

# command argument as environment variable
greet $name:
  echo "Hello $name"
