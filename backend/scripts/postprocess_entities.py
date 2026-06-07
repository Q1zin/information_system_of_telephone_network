#!/usr/bin/env python3
"""Post-process sea-orm-cli generated entities so the JSON API uses database
enum values (snake_case) and so partial payloads deserialize cleanly.

Run after:  sea-orm-cli generate entity -u <url> -o entity/src --lib --with-serde both
Then:       python3 scripts/postprocess_entities.py
"""
import pathlib
import re

SRC = pathlib.Path(__file__).resolve().parent.parent / "entity" / "src"

SKIP_FILES = {"lib.rs", "prelude.rs", "mod.rs", "serde_defaults.rs"}


def patch_enums():
    f = SRC / "sea_orm_active_enums.rs"
    text = f.read_text()

    # add Default to the derive list + a serde rename_all attribute
    text = text.replace(
        "#[derive(Debug, Clone, PartialEq, Eq, EnumIter, DeriveActiveEnum, Serialize, Deserialize)]",
        "#[derive(Debug, Clone, PartialEq, Eq, EnumIter, DeriveActiveEnum, Serialize, Deserialize, Default)]\n"
        '#[serde(rename_all = "snake_case")]',
    )

    # mark the first variant of every enum as #[default]
    text = re.sub(
        r"(pub enum \w+ \{\n)(\s*)#\[sea_orm\(string_value",
        r"\1\2#[default]\n\2#[sea_orm(string_value",
        text,
    )
    f.write_text(text)
    print("patched sea_orm_active_enums.rs")


FIELD_RE = re.compile(r"^(\s*)pub (\w+): (.+),$")


def serde_attr_for(ty: str):
    if ty.startswith("Option<"):
        return None  # serde already treats Option as optional
    if ty == "Date":
        return '#[serde(default = "crate::serde_defaults::today")]'
    if ty == "DateTimeWithTimeZone":
        return '#[serde(default = "crate::serde_defaults::now_tz")]'
    # String / bool / iNN / Decimal / enums all implement Default
    return "#[serde(default)]"


def patch_model(f: pathlib.Path):
    lines = f.read_text().splitlines()
    out = []
    for i, line in enumerate(lines):
        m = FIELD_RE.match(line)
        prev = lines[i - 1].strip() if i > 0 else ""
        # skip the primary key field (already #[serde(skip_deserializing)])
        if m and "skip_deserializing" not in prev and "serde(default" not in prev:
            indent, _name, ty = m.groups()
            attr = serde_attr_for(ty.strip())
            if attr:
                out.append(f"{indent}{attr}")
        out.append(line)
    f.write_text("\n".join(out) + "\n")


def main():
    patch_enums()
    for f in sorted(SRC.glob("*.rs")):
        if f.name in SKIP_FILES or f.name == "sea_orm_active_enums.rs":
            continue
        patch_model(f)
    print("patched model files")


if __name__ == "__main__":
    main()
