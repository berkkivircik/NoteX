"""Generate the native language catalog from the reviewed shared source.
Copyright (C) 2026 Berk Kivircik. SPDX-License-Identifier: GPL-3.0-only
"""
import json
import re
from pathlib import Path
import xml.etree.ElementTree as ET


def catalog(root: Path):
    source = (root / "PowerEditor/src/ScintillaComponent/ScintillaEditView.cpp").read_text(encoding="utf-8")
    mappings = re.findall(r'\{L"([^"]+)",\s*L"([^"]+)",\s*L"[^"]*",\s*L_\w+,\s*"([^"]+)"\}', source)
    definitions = {node.get("name"): node for node in ET.parse(root / "PowerEditor/src/langs.model.xml").findall("./Languages/Language")}
    result = []
    for name, title, lexer in mappings:
        node = definitions.get(name)
        if node is None or lexer == "user":
            continue
        result.append({"id": name, "name": title, "lexer": lexer, "extensions": node.get("ext", "").split(),
                       "lineComment": node.get("commentLine", ""), "blockOpen": node.get("commentStart", ""),
                       "blockClose": node.get("commentEnd", ""),
                       "keywords": [k.text or "" for k in node.findall("Keywords") if not k.get("name", "").startswith("substyle")]})
    if len(result) < 70:
        raise ValueError("The shared language catalog could not be parsed completely.")
    return result


if __name__ == "__main__":
    print(json.dumps(catalog(Path(__file__).resolve().parents[1]), ensure_ascii=False, indent=2))
