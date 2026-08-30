#!/usr/bin/env python3

from __future__ import annotations

from codegen import Config, Debug, Schema

from jinja2 import Environment, FileSystemLoader
from pathlib import Path

import click
import inflection


def render(template: str, config: str, schema, class_name: str, debug: bool) -> str:
    schema = schema[0] if isinstance(schema, list) and len(schema) == 1 else schema
    if not (isinstance(schema, dict) and "props" in schema):
        raise click.ClickException("Invalid schema format")

    cfg = Config.load_config(config)

    class_props = schema["props"]
    classes = []
    cls = Schema.to_class(class_name, class_props, classes)
    classes.append(cls)
    classes.reverse()

    if "renames" in cfg:
        renames = cfg["renames"]
        Config.rename_class_names(classes, Config.validate_renames(renames))

    if debug:
        Debug.print_debug(classes)

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
