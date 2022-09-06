import argparse
import os
import sys

HERE = os.path.dirname(__file__)


def main() -> None:
    """Generate docs"""
    sys.path.append(HERE)
    parser = argparse.ArgumentParser(description=main.__doc__)
    args = parser.parse_args()
    import update_readme

    update_readme.main()


if __name__ == "__main__":
    main()
