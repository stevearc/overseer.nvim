import json
import os
import re
import subprocess
from typing import Any, Dict, Iterable, List, Tuple

from apidoc import gen_api_md, gen_api_vimdoc
from util import (
    MD_LINK_PAT,
    MD_TITLE_PAT,
    Vimdoc,
    VimdocSection,
    dedent,
    format_md_table,
    indent,
    leftright,
    md_create_anchor,
    read_section,
    replace_section,
    wrap,
)

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, os.path.pardir))
README = os.path.join(ROOT, "README.md")
DOC = os.path.join(ROOT, "doc")
VIMDOC = os.path.join(DOC, "overseer.txt")

MD_BOLD_PAT = re.compile(r"\*\*([^\*]+)\*\*")
MD_LINE_BREAK_PAT = re.compile(r"\s*\\$")


def generate_toc(filename: str) -> List[str]:
    ret = []
    with open(filename, "r", encoding="utf-8") as ifile:
        for line in ifile:
            m = MD_TITLE_PAT.match(line)
            if m:
                level = len(m[1]) - 1
                prefix = "  " * level
                title_link = md_create_anchor(m[2])
                link = f"[{m[2]}](#{title_link})"
                ret.append(prefix + "- " + link + "\n")
    return ret


def read_nvim_json(lua: str) -> Any:
    cmd = f"nvim --headless --noplugin -u /dev/null -c 'set runtimepath+=.' -c 'lua print(vim.json.encode({lua}))' +qall"
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
        os.path.join(DOC, "reference.md"),
        r"^require\(\"overseer\"\).setup\({$",
        r"^}\)$",
        opt_lines,
    )


def format_param(name: str, param: Dict) -> List[str]:
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
    lines = [line]
    if param.get("long_desc"):
        lines.extend(wrap(param["long_desc"], 4, 100, ""))
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
        if comp.get("long_desc"):
            content_lines.extend(wrap(comp["long_desc"], width=100, line_end=""))
        if comp.get("params"):
            for k, v in sorted(comp["params"].items()):
                content_lines.extend(format_param(k, v))
        for i, line in enumerate(content_lines):
            if i < len(content_lines) - 1:
                content_lines[i] = line + " \\\n"
            else:
                content_lines[i] = line + "\n"
        lines.extend(content_lines)
        lines.append("\n")
    with open(doc, "w", encoding="utf-8") as ofile:
        ofile.writelines(lines)


def iter_parser_nodes() -> Iterable[Dict]:
    for filename in sorted(os.listdir(os.path.join(ROOT, "lua", "overseer", "parser"))):
        basename = os.path.splitext(filename)[0]
        if basename == "init":
            continue
        parser = read_nvim_json(
            f'require("overseer.parser").get_parser_docs("{basename}")'
        )
        if parser:
            yield parser


def format_parser_arg(arg: Dict) -> Iterable[str]:
    pieces = [f"**{arg['name']}**[`{arg['type']}`]:", arg["desc"]]
    if arg.get("default") is not None:
        pieces.append("(default `%s`)" % json.dumps(arg["default"]))
    yield " ".join(pieces) + " \\\n"
    if arg.get("long_desc"):
        yield from wrap(arg["long_desc"], 4, 100, " \\\n")
    for subarg in arg.get("fields", []):
        for line in format_parser_arg(subarg):
            yield 4 * "&nbsp;" + line


def format_parser_args(name: str, args: List[Dict]) -> Iterable[str]:
    yield "```lua\n"

    def arg_name(arg: Dict) -> str:
        if arg.get("vararg"):
            return arg["name"] + "..."
        else:
            return arg["name"]

    required_args = ['"%s"' % name] + [
        arg_name(arg) for arg in args if not arg.get("position_optional")
    ]
    yield "{" + ", ".join(required_args) + "}\n"
    all_args = ['"%s"' % name] + [arg_name(arg) for arg in args]
    if len(all_args) != len(required_args):
        yield "{" + ", ".join(all_args) + "}\n"
    yield "```\n"
    yield "\n"
    for arg in args:
        yield from format_parser_arg(arg)


def format_example_code(code: str) -> Iterable[str]:
    lines = code.split("\n")
    while re.match(r"^\s*$", lines[0]):
        lines.pop(0)
    while re.match(r"^\s*$", lines[-1]):
        lines.pop()
    for line in dedent(lines):
        yield line + "\n"


def update_parsers_md():
    doc = os.path.join(ROOT, "doc", "parsers.md")
    prefix = [
        "\n",
        "This is a list of the parser nodes that are built-in to overseer. They can be found in [lua/overseer/parser](../lua/overseer/parser)\n",
        "\n",
    ]
    toc = []
    lines = []
    for parser in iter_parser_nodes():
        toc.append(f"- [{parser['name']}](#{parser['name']})\n")
        lines.append(
            f"## [{parser['name']}](../lua/overseer/parser/{parser['name']}.lua)\n\n"
        )
        lines.append(parser["desc"] + " \\\n")
        if parser.get("long_desc"):
            lines.extend(wrap(parser["long_desc"], width=100))
        lines.append("\n")
        lines.extend(format_parser_args(parser["name"], parser["doc_args"]))
        if parser.get("examples"):
            lines.extend(["\n", "### Examples\n", "\n"])
            for example in parser["examples"]:
                lines.extend(
                    [
                        example["desc"] + "\n",
                        "\n",
                        "```lua\n",
                    ]
                )
                lines.extend(format_example_code(example["code"]))
                lines.extend(["```\n", "\n"])
        lines.append("\n")
    toc.append("\n")
    while lines[-1] == "\n":
        lines.pop()
    replace_section(
        doc,
        r"^# Parser nodes",
        None,
        prefix + toc + lines,
    )


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
                "Args": command.get("args", ""),
                "Description": command["def"]["desc"],
            }
        )
    lines.extend(format_md_table(rows, ["Command", "Args", "Description"]))
    lines.append("\n")
    replace_section(
        os.path.join(DOC, "reference.md"),
        r"^## Commands",
        r"^#",
        lines,
    )


def update_highlights_md():
    highlights = read_nvim_json('require("overseer").get_all_highlights()')
    lines = [
        "\n",
        "Overseer defines the following highlights override them to customize the colors.\n",
        "\n",
    ]
    rows = []
    for hl in highlights:
        name = hl["cmd"]
        desc = hl.get("desc")
        if desc is None:
            continue
        rows.append(
            {
                "Group": "`" + name + "`",
                "Description": desc,
            }
        )
    lines.extend(format_md_table(rows, ["Command", "Description"]))
    lines.append("\n")
    replace_section(
        README,
        r"^## Highlights",
        r"^#",
        lines,
    )


def get_commands_vimdoc() -> "VimdocSection":
    section = VimdocSection("Commands", "overseer-commands", ["\n"])
    commands = read_nvim_json('require("overseer").get_all_commands()')
    for command in commands:
        cmd = command["cmd"]
        if command["def"].get("bang"):
            cmd += "[!]"
        if "args" in command:
            cmd += " " + command["args"]
        section.body.append(leftright(cmd, f"*:{command['cmd']}*"))
        section.body.extend(wrap(command["def"]["desc"], 4))
        section.body.append("\n")
    return section


def get_options_vimdoc() -> "VimdocSection":
    section = VimdocSection("options", "overseer-options")
    config_file = os.path.join(ROOT, "lua", "overseer", "config.lua")
    opt_lines = read_section(config_file, r"^local default_config =", r"^}$")
    lines = ["\n", ">\n", '    require("overseer").setup({\n']
    lines.extend(indent(opt_lines, 4))
    lines.extend(["    })\n", "<\n"])
    section.body = lines
    return section


def get_highlights_vimdoc() -> "VimdocSection":
    section = VimdocSection("Highlights", "overseer-highlights", ["\n"])
    highlights = read_nvim_json('require("overseer").get_all_highlights()')
    for hl in highlights:
        name = hl["name"]
        desc = hl.get("desc")
        if desc is None:
            continue
        section.body.append(leftright(name, f"*hl-{name}*"))
        section.body.extend(wrap(desc, 4))
        section.body.append("\n")
    return section


def convert_md_link(match):
    text = match[1]
    dest = match[2]
    if dest.startswith("#"):
        return f"|{dest[1:]}|"
    else:
        return text


def convert_markdown_to_vimdoc(lines: List[str]) -> List[str]:
    while lines[0] == "\n":
        lines.pop(0)
    while lines[-1] == "\n":
        lines.pop()
    i = 0
    code_block = False
    while i < len(lines):
        line = lines[i]
        if line.startswith("```"):
            code_block = not code_block
            if code_block:
                lines[i] = ">\n"
            else:
                lines[i] = "<\n"
        else:
            if code_block:
                lines[i] = 4 * " " + line
            else:
                line = MD_LINK_PAT.sub(convert_md_link, line)
                line = MD_BOLD_PAT.sub(lambda x: x[1], line)
                line = MD_LINE_BREAK_PAT.sub("", line)

                if len(line) > 80:
                    new_lines = wrap(line)
                    lines[i : i + 1] = new_lines
                    i += len(new_lines)
                    continue
                else:
                    lines[i] = line
        i += 1
    return lines


def convert_md_section(
    filename: str,
    start_pat: str,
    end_pat: str,
    section_name: str,
    section_tag: str,
    inclusive: Tuple[bool, bool] = (False, False),
) -> VimdocSection:
    lines = read_section(filename, start_pat, end_pat, inclusive)
    lines = convert_markdown_to_vimdoc(lines)
    return VimdocSection(section_name, section_tag, lines)


def generate_vimdoc():
    doc = Vimdoc("overseer.txt", ["Overseer", "overseer", "overseer.nvim"])
    doc.sections.extend(
        [
            get_commands_vimdoc(),
            get_options_vimdoc(),
            get_highlights_vimdoc(),
            VimdocSection("API", "overseer-api", gen_api_vimdoc()),
            convert_md_section(
                os.path.join(DOC, "reference.md"),
                "^## Parameters",
                "^#",
                "Parameters",
                "overseer-params",
            ),
        ]
    )

    # TODO check for missing tags
    with open(VIMDOC, "w", encoding="utf-8") as ofile:
        ofile.writelines(doc.render())


def update_md_api():
    lines = ["\n"] + gen_api_md() + ["\n"]
    replace_section(
        os.path.join(DOC, "reference.md"),
        r"^<!-- API -->$",
        r"^<!-- /API -->$",
        lines,
    )


def update_md_toc(filename: str):
    toc = ["\n"] + generate_toc(filename) + ["\n"]
    replace_section(
        filename,
        r"^<!-- TOC -->$",
        r"^<!-- /TOC -->$",
        toc,
    )


def add_md_link_path(path: str, lines: List[str]) -> List[str]:
    ret = []
    for line in lines:
        ret.append(re.sub(r"(\(#)", "(" + path + "#", line))
    return ret


def update_readme_toc():
    toc = generate_toc(README)

    def get_toc(filename: str) -> List[str]:
        subtoc = generate_toc(os.path.join(DOC, filename))
        return add_md_link_path("doc/" + filename, subtoc)

    tutorials_toc = get_toc("tutorials.md")
    guides_toc = get_toc("guides.md")
    reference_toc = get_toc("reference.md")
    explanation_toc = get_toc("explanation.md")
    third_party_toc = get_toc("third_party.md")

    def add_subtoc(title: str, lines: List[str]):
        for i, line in enumerate(toc):
            if line.strip().startswith(f"- [{title}]"):
                toc[i + 1 : i + 1] = indent(
                    # Only add subtoc one level deep
                    [line for line in lines if not line.startswith(" ")],
                    2,
                )
                return
        raise Exception(f"could not find README section {title} in TOC")

    add_subtoc("Tutorials", tutorials_toc)
    add_subtoc("Guides", guides_toc)
    add_subtoc("Reference", reference_toc)
    add_subtoc("Explanation", explanation_toc)
    add_subtoc("Third-party integrations", third_party_toc)

    replace_section(
        README,
        r"^## Tutorials$",
        r"^#",
        ["\n"] + tutorials_toc + ["\n"],
    )
    replace_section(
        README,
        r"^## Guides$",
        r"^#",
        ["\n"] + guides_toc + ["\n"],
    )
    replace_section(
        README,
        r"^## Reference$",
        r"^#",
        ["\n"] + reference_toc + ["\n"],
    )
    replace_section(
        README,
        r"^## Explanation$",
        r"^#",
        ["\n"] + explanation_toc + ["\n"],
    )
    replace_section(
        README,
        r"^## Third-party integrations$",
        r"^#",
        ["\n"] + third_party_toc + ["\n"],
    )
    replace_section(
        README,
        r"^<!-- TOC -->$",
        r"^<!-- /TOC -->$",
        ["\n"] + toc + ["\n"],
    )


def main() -> None:
    """Update the README"""
    update_config_options()
    update_components_md()
    update_parsers_md()
    update_commands_md()
    update_md_api()
    update_md_toc(os.path.join(DOC, "tutorials.md"))
    update_md_toc(os.path.join(DOC, "guides.md"))
    update_md_toc(os.path.join(DOC, "reference.md"))
    update_md_toc(os.path.join(DOC, "explanation.md"))
    update_md_toc(os.path.join(DOC, "third_party.md"))
    update_readme_toc()
    generate_vimdoc()
