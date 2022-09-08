#!/usr/bin/env python
import argparse
import os
import sys

HERE = os.path.dirname(__file__)


def main() -> None:
    """Generate docs"""
    sys.path.append(HERE)
    parser = argparse.ArgumentParser(description=main.__doc__)
    parser.add_argument("command", choices=["generate", "lint"])
    args = parser.parse_args()
    if args.command == "generate":
        import update_readme

        update_readme.main()
    elif args.command == "lint":
        import lint_md_links

        lint_md_links.main()


if __name__ == "__main__":
    main()
