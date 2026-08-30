#!/usr/bin/env python3

from __future__ import annotations

from codegen import render, paths

from pathlib import Path

import click
import json
import re

paths.configure(Path(__file__).resolve().parent)


def validate_class_name(ctx, param, value: str) -> str:
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9_]*$", value):
        raise click.BadParameter("Class name must start with a letter and contain only letters, numbers and underscores.")
    return value


@click.command()
@click.option(
    "--template",
    required=True,
    type=click.Path(exists=True, readable=True, dir_okay=False),
    help="Jinja2 template file",
)
@click.option(
    "--config",
    required=False,
    type=click.Path(exists=True, readable=True, dir_okay=False),
    default=None,
    help="JSON configuration file",
)
@click.option(
    "--input",
    required=True,
    type=click.Path(exists=True, readable=True, dir_okay=False),
    help="JSON schema file",
)
@click.option(
    "--output",
    required=False,
    type=click.Path(writable=True, dir_okay=False),
    default=None,
    help="Output file (default: stdout)",
)
@click.option(
    "--class-name",
    required=True,
    callback=validate_class_name,
    help="Name of the top-level class",
)
@click.option(
    "--debug",
    required=False,
    is_flag=True,
    default=False,
    help="Print debug information",
)
def main(template, config, input, output, class_name, debug):
    with open(input) as f:
        schema = json.load(f)

    result = render.render(template, config, schema, class_name, debug)

    if output is None:
        click.echo(result)
    else:
        with open(output, "w") as f:
            f.write(result)
        click.echo(f"Saved {output}.")


if __name__ == "__main__":
    main()
