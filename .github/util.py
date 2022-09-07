"""Utility methods for generating docs"""
import re
import textwrap
from collections import defaultdict
from typing import Dict, List, Optional, Tuple


def markdown_paragraph(block: str) -> List[str]:
    return [" \\\n".join(block.rstrip().split("\n")) + "\n"]


def format_md_table_row(
    data: Dict, column_names: List[str], max_widths: Dict[str, int]
) -> str:
    cols = []
    for col in column_names:
        cols.append(data.get(col, "").ljust(max_widths[col]))
    return "| " + " | ".join(cols) + " |\n"


def format_md_table(rows: List[Dict], column_names: List[str]) -> List[str]:
    max_widths: Dict[str, int] = defaultdict(lambda: 1)
    for row in rows:
        for col in column_names:
            max_widths[col] = max(max_widths[col], len(row.get(col, "")))
    lines = []
    titles = []
    for col in column_names:
        titles.append(col.ljust(max_widths[col]))
    lines.append("| " + " | ".join(titles) + " |\n")
    seps = []
    for col in column_names:
        seps.append(max_widths[col] * "-")
    lines.append("| " + " | ".join(seps) + " |\n")
    for row in rows:
        lines.append(format_md_table_row(row, column_names, max_widths))
    return lines


def indent(lines: List[str], amount: int) -> List[str]:
    ret = []
    for line in lines:
        if not line.endswith("\n"):
            line += "\n"
        if amount >= 0:
            ret.append(" " * amount + line)
        else:
            space = re.match(r"[ \t]+", line)
            if space:
                ret.append(line[min(abs(amount), space.span()[1]) :])
            else:
                ret.append(line)
    return ret


def dedent(lines: List[str], amount: Optional[int] = None) -> List[str]:
    if amount is None:
        amount = len(lines[0])
        for line in lines:
            m = re.match(r"^\s+", line)
            if not m:
                return lines
            amount = min(amount, len(m[0]))
    return [line[amount:] for line in lines]


def replace_section(
    file: str, start_pat: str, end_pat: Optional[str], lines: List[str]
) -> None:
    prefix_lines: List[str] = []
    postfix_lines: List[str] = []
    file_lines = prefix_lines
    found_section = False
    with open(file, "r", encoding="utf-8") as ifile:
        inside_section = False
        for line in ifile:
            if inside_section:
                if end_pat is not None and re.match(end_pat, line):
                    inside_section = False
                    file_lines = postfix_lines
                    file_lines.append(line)
            else:
                if re.match(start_pat, line):
                    inside_section = True
                    found_section = True
                file_lines.append(line)
    if end_pat is None:
        inside_section = False

    if inside_section or not found_section:
        raise Exception(f"could not find file section {start_pat} in {file}")

    all_lines = prefix_lines + lines + postfix_lines
    with open(file, "w", encoding="utf-8") as ofile:
        ofile.write("".join(all_lines))


def read_section(
    filename: str,
    start_pat: str,
    end_pat: str,
    inclusive: Tuple[bool, bool] = (False, False),
) -> List[str]:
    lines = []
    with open(filename, "r", encoding="utf-8") as ifile:
        inside_section = False
        for line in ifile:
            if inside_section:
                if re.match(end_pat, line):
                    if inclusive[1]:
                        lines.append(line)
                    break
                lines.append(line)
            elif re.match(start_pat, line):
                inside_section = True
                if inclusive[0]:
                    lines.append(line)
    return lines


def count_special(base: str, char: str) -> int:
    c = base.count(char)
    return 2 * (c // 2)


def vimlen(string: str) -> int:
    return len(string) - sum([count_special(string, c) for c in "`|*"])


def leftright(left: str, right: str, width: int = 80) -> str:
    spaces = max(1, width - vimlen(left) - vimlen(right))
    return left + spaces * " " + right + "\n"


def wrap(
    text: str,
    indent: int = 0,
    width: int = 80,
    line_end: str = "\n",
    sub_indent: Optional[int] = None,
) -> List[str]:
    if sub_indent is None:
        sub_indent = indent
    return [
        line + line_end
        for line in textwrap.wrap(
            text,
            initial_indent=indent * " ",
            subsequent_indent=sub_indent * " ",
            width=width,
        )
    ]


def trim_newlines(lines: List[str]) -> List[str]:
    while lines and lines[0] == "\n":
        lines.pop(0)
    while lines and lines[-1] == "\n":
        lines.pop()
    return lines


class VimdocSection:
    def __init__(
        self,
        name: str,
        tag: str,
        body: Optional[List[str]] = None,
        sep: str = "-",
        width: int = 80,
    ):
        self.name = name
        self.tag = tag
        self.body = body or []
        self.sep = sep
        self.width = width

    def get_body(self) -> List[str]:
        return self.body

    def render(self) -> List[str]:
        lines = [
            self.width * self.sep + "\n",
            leftright(self.name.upper(), f"*{self.tag}*", self.width),
            "\n",
        ]
        lines.extend(trim_newlines(self.get_body()))
        lines.append("\n")
        return lines


class VimdocToc(VimdocSection):
    def __init__(self, name: str, tag: str, width: int = 80):
        super().__init__(name, tag, width=width)
        self.entries: List[Tuple[str, str]] = []
        self.padding = 2

    def get_body(self) -> List[str]:
        lines = []
        for i, (name, tag) in enumerate(self.entries):
            left = self.padding * " " + f"{i+1}. {name.capitalize()}"
            tag_start = self.width - 2 * self.padding - vimlen(tag)
            lines.append(left.ljust(tag_start, ".") + f"|{tag}|\n")
        return lines


class Vimdoc:
    def __init__(self, filename: str, tags: List[str], width: int = 80):
        self.prefix = [f"*{filename}*\n", " ".join(f"*{tag}*" for tag in tags) + "\n"]
        self.sections: List[VimdocSection] = []
        self.width = width

    def render(self) -> List[str]:
        header = self.prefix[:]
        body = []
        toc = VimdocToc("CONTENTS", "overseer-contents", width=self.width)
        for section in self.sections:
            toc.entries.append((section.name, section.tag))
            body.extend(section.render())
        body.append(self.width * "=" + "\n")
        body.append("vim:tw=80:ts=2:ft=help:norl:syntax=help:\n")
        return header + toc.render() + body
