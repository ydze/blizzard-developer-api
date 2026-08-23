#!/usr/bin/env python3

import json
import click
import inflection
import re
from dataclasses import dataclass, field
from jinja2 import Environment, FileSystemLoader
from pathlib import Path


@dataclass
class PseudoProperty:
    name: str
    type: str
    nullable: bool
    types: list[str] = field(default_factory=list)


@dataclass
class PseudoClass:
    name: str
    properties: list[PseudoProperty] = field(default_factory=list)
    nested_classes: list["PseudoClass"] = field(default_factory=list)


CSHARP_TYPE_MAP = {
    "string": "string",
    "number": "long",
    "boolean": "bool",
}


def validate_class_name(ctx, param, value):
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9_]*$", value):
        raise click.BadParameter(
            "Class name must start with a letter and contain only letters, numbers and underscores."
        )
    return value


def describe_array(arr: list) -> str:
    return f"[{describe_proptype(arr)}]"


def describe_object(obj: dict) -> str:
    parts = [
        f'"{p["propname"]}": {describe_proptype(p["proptype"])}' for p in obj["props"]
    ]
    return f"{{{', '.join(parts)}}}"


def describe_proptype(proptype: list) -> str:
    parts = []
    for t in proptype:
        if isinstance(t, str) and t != "null":
            parts.append(CSHARP_TYPE_MAP.get(t, t))
        elif isinstance(t, list):
            parts.append(describe_array(t))
        elif isinstance(t, dict) and "props" in t:
            parts.append(describe_object(t))
    return f"{', '.join(parts)}"


def resolve_csharp_type(proptype: list, nullable: bool) -> tuple[str, list[str]]:
    """
    Returns (csharp_type, all_types) tuple.
    all_types is used for XML doc comment when type is dynamic.
    """
    has_null = "null" in proptype
    is_nullable = nullable or has_null
    types = [t for t in proptype if t != "null"]

    scalars = [t for t in types if isinstance(t, str)]
    arrays = [t for t in types if isinstance(t, list)]
    objects = [t for t in types if isinstance(t, dict) and "props" in t]

    nullable_suffix = "?" if is_nullable else ""

    # single scalar type
    if len(scalars) == 1 and not arrays and not objects:
        return CSHARP_TYPE_MAP.get(scalars[0], scalars[0]) + nullable_suffix, []

    # single array type
    if len(arrays) == 1 and not scalars and not objects:
        inner_type, inner_types = resolve_csharp_type(arrays[0], False)
        # mixed element types — dynamic array with doc comment
        if inner_types:
            return f"dynamic[]{nullable_suffix}", [describe_array(arrays[0])]
        return f"{inner_type}[]{nullable_suffix}", []

    # single object type — handled separately in schema_to_class
    if len(objects) == 1 and not scalars and not arrays:
        return None, []  # signal to use nested class name

    all_type_names = (
        [CSHARP_TYPE_MAP.get(s, s) for s in scalars]
        + [describe_array(a) for a in arrays]
        + [describe_object(o) for o in objects]
    )

    # multiple types — use dynamic
    return f"dynamic{nullable_suffix}", all_type_names


def schema_to_class(name: str, props: list, classes: list) -> PseudoClass:
    cls = PseudoClass(name=name)

    for prop in props:
        propname = prop["propname"]
        proptype = prop["proptype"]
        nullable = prop["nullable"]

        has_null = "null" in proptype
        is_nullable = nullable or has_null
        nullable_suffix = "?" if is_nullable else ""

        objects = [t for t in proptype if isinstance(t, dict) and "props" in t]

        if len(proptype) == 1 and objects:
            # single nested object — generate nested class
            nested_name = inflection.camelize(propname)
            nested_class = schema_to_class(nested_name, objects[0]["props"], classes)
            classes.append(nested_class)
            csharp_type = nested_name + nullable_suffix
            all_types = []
        else:
            csharp_type, all_types = resolve_csharp_type(proptype, nullable)

        cls.properties.append(
            PseudoProperty(
                name=inflection.camelize(propname),
                type=csharp_type,
                nullable=is_nullable,
                types=all_types,
            )
        )

    return cls


def render(schema: list | dict, class_name: str, template: str) -> str:
    if isinstance(schema, list):
        root_props = schema[0]["props"]
    elif isinstance(schema, dict) and "props" in schema:
        root_props = schema["props"]
    else:
        raise click.ClickException("Invalid schema format")

    classes = []
    root = schema_to_class(class_name, root_props, classes)
    classes.insert(0, root)

    template_path = Path(template)
    env = Environment(
        loader=FileSystemLoader(str(template_path.parent)),
        lstrip_blocks=True,
        trim_blocks=True,
    )

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
    help="Name of the root class",
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


if __name__ == "__main__":
    main()
