#!/usr/bin/env python3

import click
import inflection
import json
import re
from dataclasses import dataclass, field, asdict
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
    nullable: bool
    possible_types: list["PseudoPropertyType"] = field(default_factory=list)


@dataclass
class PseudoProperty:
    propname: str
    proptype: PseudoPropertyType
    missing: bool


@dataclass
class PseudoClass:
    name: str
    properties: list[PseudoProperty] = field(default_factory=list)


def resolve_type(propname: str, proptype: list, classes: list) -> PseudoPropertyType:
    is_nullable = not proptype or "null" in proptype
    types = [t for t in proptype if t != "null"]

    scalars = [t for t in types if isinstance(t, str)]
    arrays = [t for t in types if isinstance(t, list)]
    objects = [t for t in types if isinstance(t, dict) and "props" in t]

    # single scalar
    if len(scalars) == 1 and not arrays and not objects:
        scalar = scalars[0]
        return PseudoPropertyType(
            kind=PseudoPropertyKind.SCALAR, type=scalar, nullable=is_nullable
        )

    # single array
    if len(arrays) == 1 and not scalars and not objects:
        array = arrays[0]
        inner = resolve_type(propname, array, classes)
        return PseudoPropertyType(
            kind=PseudoPropertyKind.ARRAY, type=inner, nullable=is_nullable
        )

    # single object
    if len(objects) == 1 and not scalars and not arrays:
        nested_name = propname
        nested_props = objects[0]["props"]
        nested_class = schema_to_class(nested_name, nested_props, classes)
        classes.append(nested_class)
        return PseudoPropertyType(
            kind=PseudoPropertyKind.OBJECT, type=nested_name, nullable=is_nullable
        )

    # zero or many types — any (unknown type)
    return PseudoPropertyType(
        kind=PseudoPropertyKind.ANY,
        type="any",
        nullable=is_nullable,
        possible_types=[resolve_type(propname, [t], classes) for t in types],
    )


def schema_to_class(class_name: str, class_props: list, classes: list) -> PseudoClass:
    cls = PseudoClass(name=class_name)

    for prop in class_props:
        propname = prop["propname"]
        proptype = prop["proptype"]
        missing = prop["missing"]

        pseudo_type = resolve_type(propname, proptype, classes)

        cls.properties.append(
            PseudoProperty(propname=propname, proptype=pseudo_type, missing=missing)
        )

    return cls


def validate_class_name(ctx, param, value):
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9_]*$", value):
        raise click.BadParameter(
            "Class name must start with a letter and contain only letters, numbers and underscores."
        )
    return value


def print_debug(classes: list):
    title = " Class Schematics "
    title_length = (80 - len(title) - 1) // 2
    print(f"╔{"═" * title_length}{title}{"═" * title_length}╗")
    for cls in classes:
        prefix = "╠══ "
        prefix_length = len(prefix)
        class_name = f"{prefix}{cls.name} "
        class_name_length = 80 - len(class_name) - 1
        print(f"{class_name}{"═" * class_name_length}{"╣"}")
        json_str = json.dumps(
            asdict(cls),
            indent=2,
            default=lambda o: o.value if isinstance(o, Enum) else str(o),
        )
        indented = "\n".join(
            f"{" " * prefix_length}{line}" for line in json_str.splitlines()
        )
        print(indented)
    print(f"╚{"═" * 78}╝\n")


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
@click.option(
    "--debug",
    required=False,
    is_flag=True,
    default=False,
    help="Print debug information",
)
def main(template, input, output, class_name, debug):
    with open(input) as f:
        schema = json.load(f)

    root_schema = schema[0] if isinstance(schema, list) and len(schema) == 1 else schema

    if not isinstance(root_schema, dict) and not "props" in root_schema:
        raise click.ClickException("Invalid schema format")

    class_props = root_schema["props"]
    classes = []
    root = schema_to_class(class_name, class_props, classes)
    classes.append(root)
    classes.reverse()

    if debug:
        print_debug(classes=classes)

    template_path = Path(template)
    env = Environment(
        loader=FileSystemLoader(str(template_path.parent)),
        lstrip_blocks=True,
        trim_blocks=True,
    )
    env.filters["camelize"] = inflection.camelize

    tmpl = env.get_template(template_path.name)
    result = tmpl.render(classes=classes).strip()

    if output is None:
        click.echo(result)
    else:
        with open(output, "w") as f:
            f.write(result)
        click.echo(f"Saved {output}.")


if __name__ == "__main__":
    main()
