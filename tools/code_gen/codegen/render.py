#!/usr/bin/env python3

from __future__ import annotations

from codegen import config, debug, renames, schema

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
    if "renames" in cfg:
        subs = cfg["renames"]
        renames.rename_class_names(classes, config.validate_renames(subs))


def render(template_path: str, config_path: str, json_schema, class_name: str, debug_enabled: bool) -> str:
    json_schema = normalize_schema(json_schema)

    cfg = config.load_config(config_path)

    class_props = json_schema["props"]
    classes = []
    cls = schema.to_class(class_name, class_props, classes)
    classes.append(cls)
    classes.reverse()

    apply_config(cfg, classes)

    if debug_enabled:
        debug.print_debug(classes)

    template = Path(template_path)
    env = Environment(
        loader=FileSystemLoader(str(template.parent)),
        lstrip_blocks=True,
        trim_blocks=True,
    )
    env.filters["camelize"] = inflection.camelize

    tmpl = env.get_template(template.name)
    result = tmpl.render(classes=classes).strip()
    return result
