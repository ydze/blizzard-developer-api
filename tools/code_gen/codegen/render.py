#!/usr/bin/env python3

from __future__ import annotations

from codegen import config, debug, schema

from jinja2 import Environment, FileSystemLoader
from pathlib import Path

import click
import inflection


def render(template_path: str, config_path: str, json_schema, class_name: str, debug_enabled: bool) -> str:
    json_schema = json_schema[0] if isinstance(json_schema, list) and len(json_schema) == 1 else json_schema
    if not (isinstance(json_schema, dict) and "props" in json_schema):
        raise click.ClickException("Invalid schema format")

    cfg = config.load_config(config_path)

    class_props = json_schema["props"]
    classes = []
    cls = schema.to_class(class_name, class_props, classes)
    classes.append(cls)
    classes.reverse()

    if "renames" in cfg:
        renames = cfg["renames"]
        config.rename_class_names(classes, config.validate_renames(renames))

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
