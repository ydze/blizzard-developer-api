#!/usr/bin/env python3

from __future__ import annotations

from codegen.config import load_config, validate_dictionaries, validate_renames
from codegen.debug import print_debug
from codegen.dictionaries import apply_dictionaries
from codegen.renames import apply_renames
from codegen.schema import to_class

from jinja2 import Environment, FileSystemLoader
from pathlib import Path

import click
import inflection


def normalize_schema(schema):
    if isinstance(schema, list) and len(schema) == 1:
        return schema[0]

    if isinstance(schema, dict) and "props" in schema:
        return schema

    raise click.ClickException("Invalid schema format")


def apply_config(cfg: dict, classes: list):
    if "dictionaries" in cfg:
        names = cfg["dictionaries"]
        apply_dictionaries(classes, validate_dictionaries(names))

    if "renames" in cfg:
        renames = cfg["renames"]
        apply_renames(classes, validate_renames(renames))


def render(template: str, config: str, schema, class_name: str, debug: bool) -> str:
    schema = normalize_schema(schema)

    cfg = load_config(config)

    class_props = schema["props"]
    classes = []
    cls = to_class(class_name, class_props, classes)
    classes.append(cls)
    classes.reverse()

    apply_config(cfg, classes)

    if debug:
        print_debug(classes)

    template_path = Path(template)
    env = Environment(
        loader=FileSystemLoader(str(template_path.parent)),
        lstrip_blocks=True,
        trim_blocks=True,
    )
    env.filters["camelize"] = inflection.camelize

    tmpl = env.get_template(template_path.name)
    result = tmpl.render(classes=classes).strip()
    return result
