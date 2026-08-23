#!/usr/bin/env python3

import json
import click
import inflection
import re
from dataclasses import dataclass, field
from enum import Enum
from jinja2 import Environment, FileSystemLoader
from pathlib import Path


class PseudoPropertyKind(Enum):
    ANY = "ANY"
    ARRAY = "ARRAY"
    OBJECT = "OBJECT"
    SCALAR = "SCALAR"


@dataclass
class PseudoPropertyType:
    kind: PseudoPropertyKind
    type: str | "PseudoPropertyType"
    possible_types: list["PseudoPropertyType"] = field(default_factory=list)


@dataclass
class PseudoProperty:
    propname: str
    proptype: PseudoPropertyType
    nullable: bool


@dataclass
class PseudoClass:
    name: str
    properties: list[PseudoProperty] = field(default_factory=list)
    nested_classes: list["PseudoClass"] = field(default_factory=list)


def validate_class_name(ctx, param, value):
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9_]*$", value):
        raise click.BadParameter(
            "Class name must start with a letter and contain only letters, numbers and underscores."
        )
    return value


def resolve_type(propname: str, proptype: list, classes: list) -> PseudoPropertyType:
    types = [t for t in proptype if t != "null"]

    scalars = [t for t in types if isinstance(t, str)]
    arrays = [t for t in types if isinstance(t, list)]
    objects = [t for t in types if isinstance(t, dict) and "props" in t]

    # only null — unknown type
    if not types:
        return PseudoPropertyType(
            kind=PseudoPropertyKind.ANY,
            type="any",
            possible_types=[
                PseudoPropertyType(kind=PseudoPropertyKind.SCALAR, type=proptype[0])
            ],
        )

    # single scalar
    if len(scalars) == 1 and not arrays and not objects:
        return PseudoPropertyType(kind=PseudoPropertyKind.SCALAR, type=scalars[0])

    # single array
    if len(arrays) == 1 and not scalars and not objects:
        inner = resolve_type(propname, arrays[0], classes)
        return PseudoPropertyType(kind=PseudoPropertyKind.ARRAY, type=inner)

    # single object
    if len(objects) == 1 and not scalars and not arrays:
        nested_name = propname
        nested_class = schema_to_class(nested_name, objects[0]["props"], classes)
        classes.append(nested_class)
        return PseudoPropertyType(kind=PseudoPropertyKind.OBJECT, type=nested_name)

    # multiple types — any
    return PseudoPropertyType(
        kind=PseudoPropertyKind.ANY,
        type="any",
        possible_types=[resolve_type(propname, [t], classes) for t in types],
    )


def schema_to_class(name: str, props: list, classes: list) -> PseudoClass:
    cls = PseudoClass(name=name)

    for prop in props:
        propname = prop["propname"]
        proptype = prop["proptype"]
        nullable = prop["nullable"]

        has_null = "null" in proptype
        is_nullable = nullable or has_null

        pseudo_type = resolve_type(propname, proptype, classes)

        cls.properties.append(
            PseudoProperty(
                propname=propname,
                proptype=pseudo_type,
                nullable=is_nullable,
            )
        )

    return cls


def render(schema: list | dict, class_name: str, template: str) -> str:
    if isinstance(schema, list) and "props" in schema[0]:
        class_props = schema[0]["props"]
    elif isinstance(schema, dict) and "props" in schema:
        class_props = schema["props"]
    else:
        raise click.ClickException("Invalid schema format")

    classes = []
    root = schema_to_class(class_name, class_props, classes)
    classes.insert(0, root)

    template_path = Path(template)
    env = Environment(
        loader=FileSystemLoader(str(template_path.parent)),
        lstrip_blocks=True,
        trim_blocks=True,
    )
    env.filters["camelize"] = inflection.camelize

    tmpl = env.get_template(template_path.name)
    return tmpl.render(classes=classes)


@click.command()
@click.option(
    "--template",
    required=True,
    type=click.Path(exists=True, readable=True, dir_okay=False),
    help="Jinja2 template file",
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
def main(template, input, output, class_name):
    with open(input) as f:
        schema = json.load(f)

    result = render(schema, class_name, template)

    if output is None:
        click.echo(result)
    else:
        with open(output, "w") as f:
            f.write(result)
        click.echo(f"Saved {output}.")


if __name__ == "__main__":
    main()
