#!/usr/bin/env python3

from __future__ import annotations

from codegen.debug import print_debug
from codegen.dictionaries import apply_dictionaries
from codegen.models import CodegenContext
from codegen.renames import apply_renames
from codegen.schema import to_class

from jinja2 import Environment, FileSystemLoader

import click
import inflection


def normalize_schema(schema):
    if isinstance(schema, list) and len(schema) == 1:
        return schema[0]

    if isinstance(schema, dict) and "props" in schema:
        return schema

    raise click.ClickException("Invalid schema format")


def apply_config(ctx: CodegenContext):
    apply_dictionaries(ctx)
    apply_renames(ctx)


def render(ctx: CodegenContext, schema) -> str:
    schema = normalize_schema(schema)

    class_props = schema["props"]
    cls = to_class(ctx, "root", class_props)
    ctx.classes.append(cls)
    ctx.classes.reverse()

    apply_config(ctx)

    print_debug(ctx)

    env = Environment(
        loader=FileSystemLoader(str(ctx.template_path.parent)),
        lstrip_blocks=True,
        trim_blocks=True,
    )
    env.filters["camelize"] = inflection.camelize

    tmpl = env.get_template(ctx.template_path.name)
    result = tmpl.render(classes=ctx.classes).strip()
    return result
