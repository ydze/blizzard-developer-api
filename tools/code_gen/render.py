#!/usr/bin/env python3

from __future__ import annotations

from codegen import render, paths
from codegen.config import load_config
from codegen.models import CodegenContext

from pathlib import Path

import click
import json

paths.configure(Path(__file__).resolve().parent)


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
    "--debug",
    required=False,
    is_flag=True,
    default=False,
    help="Print debug information",
)
def main(template, config, input, output, debug):
    template_path = Path(template)
    cfg = load_config(config)
    ctx = CodegenContext(template_path, cfg, debug)

    with open(input) as f:
        schema = json.load(f)

    result = render.render(ctx, schema)

    if output is None:
        click.echo(result)
    else:
        with open(output, "w") as f:
            f.write(result)
        click.echo(f"Saved {output}.")


if __name__ == "__main__":
    main()
