#!/usr/bin/env python3
import json
import click
from jinja2 import Environment, FileSystemLoader
from pathlib import Path

@click.command()
@click.option("--template", required=True, type=click.Path(exists=True), help="Path to Jinja2 template file")
@click.option("--input", required=True, type=click.Path(exists=True), help="Path to JSON schema file")
@click.option("--output", default="-", help="Output file path (default: stdout)")
def render(template, input, output):
    template_path = Path(template)

    env = Environment(
        loader=FileSystemLoader(str(template_path.parent)),
        trim_blocks=True,
        lstrip_blocks=True
    )

    with open(input) as f:
        schema = json.load(f)

    tmpl = env.get_template(template_path.name)
    result = tmpl.render(schema=schema)

    if output == "-":
        click.echo(result)
    else:
        with open(output, "w") as f:
            f.write(result)

if __name__ == "__main__":
    render()