#!/usr/bin/env python
import json
import os
import os.path
import re
import subprocess
import textwrap
from collections import defaultdict
from typing import Any, Dict, List

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, os.path.pardir))
README = os.path.join(ROOT, "README.md")
DOC = os.path.join(ROOT, "doc", "overseer.txt")


def indent(lines: List[str], amount: int) -> List[str]:
    ret = []
    for line in lines:
        if amount >= 0:
            ret.append(" " * amount + line)
        else:
            space = re.match(r"[ \t]+", line)
            if space:
                ret.append(line[min(abs(amount), space.span()[1]) :])
            else:
                ret.append(line)
    return ret


def replace_section(file: str, start_pat: str, end_pat: str, lines: List[str]) -> None:
    prefix_lines: List[str] = []
    postfix_lines: List[str] = []
    file_lines = prefix_lines
    found_section = False
    with open(file, "r", encoding="utf-8") as ifile:
        inside_section = False
        for line in ifile:
            if inside_section:
                if re.match(end_pat, line):
                    inside_section = False
                    file_lines = postfix_lines
                    file_lines.append(line)
            else:
                if re.match(start_pat, line):
                    inside_section = True
                    found_section = True
                file_lines.append(line)

    if inside_section or not found_section:
        raise Exception(f"could not find file section {start_pat}")

    all_lines = prefix_lines + lines + postfix_lines
    with open(file, "w", encoding="utf-8") as ofile:
        ofile.write("".join(all_lines))


def read_section(filename: str, start_pat: str, end_pat: str) -> List[str]:
    lines = []
    with open(filename, "r", encoding="utf-8") as ifile:
        inside_section = False
        for line in ifile:
            if inside_section:
                if re.match(end_pat, line):
                    break
                lines.append(line)
            elif re.match(start_pat, line):
                inside_section = True
    return lines


def read_nvim_json(lua: str) -> Any:
    cmd = f"""nvim --headless --noplugin -u /dev/null -c 'set runtimepath+=.' -c 'lua print(vim.json.encode({lua}))' +qall"""
    print(cmd)
    code, txt = subprocess.getstatusoutput(cmd)
    if code != 0:
        raise Exception(f"Error exporting data from overseer: {txt}")
    try:
        return json.loads(txt)
    except json.JSONDecodeError as e:
        raise Exception(f"Json decode error: {txt}") from e


def update_config_options():
    config_file = os.path.join(ROOT, "lua", "overseer", "config.lua")
    opt_lines = read_section(config_file, r"^local default_config =", r"^}$")
    replace_section(
        README,
        r"^require\(\"overseer\"\).setup\({$",
        r"^}\)$",
        opt_lines,
    )


def format_param(name: str, param: Dict) -> str:
    typestr = param["type"]
    if "subtype" in param:
        typestr += "[" + str(param["subtype"]["type"]) + "]"
    pieces = [f"**{name}**[{typestr}]:"]
    required = not param.get("optional")
    if param.get("desc"):
        pieces.append(param["desc"])
    if param.get("default") is not None:
        pieces.append("(default `%s`)" % json.dumps(param["default"]))
        required = False
    line = " ".join(pieces)
    if required:
        line = "\\*" + line
    return line


def format_md_table_row(
    data: Dict, column_names: List[str], max_widths: Dict[str, int]
) -> str:
    cols = []
    for col in column_names:
        cols.append(data[col].ljust(max_widths[col]))
    return "| " + " | ".join(cols) + " |\n"


def format_md_table(rows: List[Dict], column_names: List[str]) -> List[str]:
    max_widths: Dict[str, int] = defaultdict(lambda: 1)
    for row in rows:
        for col in column_names:
            max_widths[col] = max(max_widths[col], len(row[col]))
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


def update_components_md():
    components = read_nvim_json('require("overseer.component").get_all_descriptions()')
    doc = os.path.join(ROOT, "doc", "components.md")
    lines = ["# Built-in components\n", "\n"]
    for comp in components:
        title = f"## [{comp['name']}](../lua/overseer/component/{comp['name']}.lua)\n\n"
        lines.append(title)
        content_lines = []
        if comp.get("desc"):
            content_lines.append(comp["desc"])
        if comp.get("params"):
            for k, v in sorted(comp["params"].items()):
                content_lines.append(format_param(k, v))
        for i, line in enumerate(content_lines):
            if i < len(content_lines) - 1:
                content_lines[i] = line + " \\\n"
            else:
                content_lines[i] = line + "\n"
        lines.extend(content_lines)
        lines.append("\n")
    with open(doc, "w", encoding="utf-8") as ofile:
        ofile.writelines(lines)


def update_commands_md():
    commands = read_nvim_json('require("overseer").get_all_commands()')
    lines = ["\n"]
    rows = []
    for command in commands:
        cmd = command["cmd"]
        if command["def"].get("bang"):
            cmd += "[!]"
        rows.append(
            {
                "Command": "`" + cmd + "`",
                "arg": command.get("args", ""),
                "description": command["def"]["desc"],
            }
        )
    lines.extend(format_md_table(rows, ["Command", "arg", "description"]))
    lines.append("\n")
    replace_section(
        README,
        r"^## Commands",
        r"^#",
        lines,
    )


def leftright(left: str, right: str, width: int = 80) -> str:
    return left + right.rjust(max(1, width - len(left) - 1)) + "\n"


def wrap(text: str, indent: int = 0, width: int = 80) -> List[str]:
    return [
        line + "\n"
        for line in textwrap.wrap(
            text,
            initial_indent=indent * " ",
            subsequent_indent=indent * " ",
            width=width,
        )
    ]


def update_commands_vimdoc():
    commands = read_nvim_json('require("overseer").get_all_commands()')
    lines = ["\n"]
    for command in commands:
        cmd = command["cmd"]
        if command["def"].get("bang"):
            cmd += "[!]"
        if "args" in command:
            cmd += " " + command["args"]
        lines.append(leftright(cmd, f"*:{command['cmd']}*", 82))
        lines.extend(wrap(command["def"]["desc"], 4))
        lines.append("\n")
    replace_section(
        DOC,
        r"^COMMANDS",
        r"^-",
        lines,
    )


def main() -> None:
    """Update the README"""
    update_config_options()
    update_components_md()
    update_commands_md()
    update_commands_vimdoc()


if __name__ == "__main__":
    main()
