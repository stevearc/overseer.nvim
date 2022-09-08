import itertools
import os
import re
import sys
from functools import lru_cache
from typing import List

from util import MD_LINK_PAT, MD_TITLE_PAT, md_create_anchor

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, os.path.pardir))
README = os.path.join(ROOT, "README.md")
DOC = os.path.join(ROOT, "doc")


@lru_cache
def read(filename: str) -> str:
    with open(filename, "r", encoding="utf-8") as ifile:
        return ifile.read()


def validate_anchor(filename: str, anchor: str) -> bool:
    text = read(filename)
    for match in re.finditer(MD_TITLE_PAT, text):
        title = match[2]
        link_match = MD_LINK_PAT.match(title)
        if link_match:
            title = link_match[1]
        if anchor == md_create_anchor(title):
            return True
    return False


def lint_file(filename: str) -> List[str]:
    errors = []
    text = read(filename)

    for match in re.finditer(MD_LINK_PAT, text):
        link = match[2]
        if re.match(r"^<?http", link):
            continue
        pieces = link.split("#")
        if len(pieces) == 1:
            linkfile, anchor = pieces[0], None
        elif len(pieces) == 2:
            linkfile, anchor = pieces
        else:
            raise ValueError(f"Invalid link {link}")
        if linkfile:
            abs_linkfile = os.path.join(os.path.dirname(filename), linkfile)
        else:
            abs_linkfile = filename

        relfile = os.path.relpath(filename, ROOT)
        if not os.path.exists(abs_linkfile):
            errors.append(f"{relfile} invalid link: {link}")
        elif anchor and not validate_anchor(abs_linkfile, anchor):
            errors.append(f"{relfile} invalid link anchor: {link}")

    return errors


def discover_files() -> List[str]:
    return [README] + [
        os.path.join(DOC, file) for file in os.listdir(DOC) if file.endswith(".md")
    ]


def main() -> None:
    """Main method"""
    errors = list(
        itertools.chain.from_iterable([lint_file(file) for file in discover_files()])
    )
    for error in errors:
        print(error)
    sys.exit(len(errors))
