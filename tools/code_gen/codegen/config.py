#!/usr/bin/env python3

from __future__ import annotations

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
    all_str = all(isinstance(k, str) and isinstance(v, str) for k, v in renames.items()) if is_dict else False
    if not is_dict or not all_str:
        raise click.ClickException("'renames' must be a JSON object of {generated_name: custom_name} string pairs.")
    return renames


def validate_dictionaries(names) -> list[str]:
    is_list = isinstance(names, list)
    all_str = all(isinstance(n, str) for n in names) if is_list else False
    if not is_list or not all_str:
        raise click.ClickException("'dictionaries' must be a JSON array of class name strings.")
    return names
