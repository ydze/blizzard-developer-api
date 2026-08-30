#!/usr/bin/env python3

from __future__ import annotations

from codegen.models import PseudoClass, PseudoProperty, PseudoPropertyType, PseudoPropertyKind

import click
import json


def load_config(path: str | None) -> dict:
    if path is None:
        return {}
    with open(path) as f:
        config = json.load(f)
    if not isinstance(config, dict):
        raise click.ClickException("Config file must be a JSON object.")
    return config


def validate_renames(renames) -> dict[str, str]:
    is_dict = isinstance(renames, dict)
    all_str = all(isinstance(k, str) and isinstance(v, str) for k, v in renames.items())
    if not is_dict or not all_str:
        raise click.ClickException("'renames' must be a JSON object of {generated_name: custom_name} string pairs.")
    return renames


def rename_property_names(proptype: PseudoPropertyType, renames: dict[str, str]):
    match proptype.kind:
        case PseudoPropertyKind.OBJECT:
            proptype.type = renames.get(proptype.type, proptype.type)
        case PseudoPropertyKind.ARRAY:
            rename_property_names(proptype.type, renames)
        case PseudoPropertyKind.ANY:
            for pt in proptype.possible_types:
                rename_property_names(pt, renames)


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
