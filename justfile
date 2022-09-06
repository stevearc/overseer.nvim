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
  python .github/main.py

# command argument as environment variable
greet $name:
  echo "Hello $name"
