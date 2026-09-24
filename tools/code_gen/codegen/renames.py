#!/usr/bin/env python3

from __future__ import annotations

from codegen.config import validate_renames
from codegen.models import CodegenContext, PseudoClass, PseudoPropertyType, PseudoPropertyKind, as_typename, as_proptype, as_kvp

import click


def rename_property_names(proptype: PseudoPropertyType, renames: dict[str, str]):
    match proptype.kind:
        case PseudoPropertyKind.OBJECT:
            proptype.type = renames.get(as_typename(proptype.type), proptype.type)

        case PseudoPropertyKind.ARRAY:
            rename_property_names(as_proptype(proptype.type), renames)

        case PseudoPropertyKind.ANY:
            for pt in proptype.possible_types:
                rename_property_names(pt, renames)

        case PseudoPropertyKind.DICT:
            rename_property_names(as_kvp(proptype.type).value_type, renames)


def rename_class_names(classes: list[PseudoClass], renames: dict[str, str]):
    class_names = {cls.name for cls in classes}

    for cls in classes:
        if cls.name in renames:
            new_name = renames[cls.name]
            if new_name != cls.name and new_name in class_names:
                raise click.ClickException(f"Rename collision: '{new_name}' is already used by another class.")
            class_names.discard(cls.name)
            class_names.add(new_name)
            cls.name = new_name

    for cls in classes:
        for prop in cls.properties:
            rename_property_names(prop.proptype, renames)


def apply_renames(ctx: CodegenContext):
    if "renames" in ctx.config:
        renames = ctx.config["renames"]
        rename_class_names(ctx.classes, validate_renames(renames))
