#!/usr/bin/env python3

from __future__ import annotations

from codegen.Models import PseudoClass, PseudoProperty, PseudoPropertyType, PseudoPropertyKind


def to_type(propname: str, proptype: list, classes: list[PseudoClass], parent_name: str) -> PseudoPropertyType:
    is_nullable = not proptype or "null" in proptype
    types = [t for t in proptype if t != "null"]

    scalars = [t for t in types if isinstance(t, str)]
    arrays = [t for t in types if isinstance(t, list)]
    objects = [t for t in types if isinstance(t, dict) and "props" in t]

    # single scalar
    if len(scalars) == 1 and not arrays and not objects:
        scalar = scalars[0]
        return PseudoPropertyType(PseudoPropertyKind.SCALAR, scalar, is_nullable)

    # single array
    if len(arrays) == 1 and not scalars and not objects:
        array = arrays[0]
        inner = to_type(propname, array, classes, parent_name)
        return PseudoPropertyType(PseudoPropertyKind.ARRAY, inner, is_nullable)

    # single object
    if len(objects) == 1 and not scalars and not arrays:
        nested_name = f"{parent_name}_{propname}"
        nested_props = objects[0]["props"]
        nested_class = to_class(nested_name, nested_props, classes)
        classes.append(nested_class)
        return PseudoPropertyType(PseudoPropertyKind.OBJECT, nested_name, is_nullable)

    # zero or many types — any (unknown type)
    return PseudoPropertyType(
        PseudoPropertyKind.ANY,
        "any",
        is_nullable,
        [to_type(propname, [t], classes, parent_name) for t in types],
    )


def to_class(name: str, properties: list, classes: list[PseudoClass]) -> PseudoClass:
    cls = PseudoClass(name)

    for prop in properties:
        propname = prop["propname"]
        proptype = prop["proptype"]
        missing = prop["missing"]

        pseudo_type = to_type(propname, proptype, classes, name)

        cls.properties.append(PseudoProperty(propname, pseudo_type, missing))

    return cls
