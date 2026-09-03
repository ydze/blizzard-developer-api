#!/usr/bin/env python3

from __future__ import annotations

from codegen.models import PseudoClass, PseudoProperty, PseudoPropertyType, PseudoKeyValuePair, PseudoPropertyKind

import click


def _flatten_any(proptypes: list[PseudoPropertyType]) -> list[PseudoPropertyType]:
    flat: list[PseudoPropertyType] = []
    for pt in proptypes:
        if pt.kind == PseudoPropertyKind.ANY:
            flat.extend(pt.possible_types)
        else:
            flat.append(pt)
    return flat


def _merge_scalars(scalars: list[PseudoPropertyType]) -> list[PseudoPropertyType]:
    nullable_by_type: dict[str, bool] = {}
    order: list[str] = []
    for pt in scalars:
        if pt.type not in nullable_by_type:
            nullable_by_type[pt.type] = pt.nullable
            order.append(pt.type)
        else:
            nullable_by_type[pt.type] = nullable_by_type[pt.type] or pt.nullable
    return [PseudoPropertyType(PseudoPropertyKind.SCALAR, t, nullable_by_type[t]) for t in order]


def _merge_arrays(
    arrays: list[PseudoPropertyType],
    classes: list[PseudoClass],
    classes_by_name: dict[str, PseudoClass],
    name: str,
) -> PseudoPropertyType:

    nullable = any(pt.nullable for pt in arrays)
    inner = _merge_types([pt.type for pt in arrays], classes, classes_by_name, f"{name}_item")
    return PseudoPropertyType(PseudoPropertyKind.ARRAY, inner, nullable)


def _merge_objects(
    objects: list[PseudoPropertyType],
    classes: list[PseudoClass],
    classes_by_name: dict[str, PseudoClass],
    name: str,
) -> PseudoPropertyType:

    nullable = any(pt.nullable for pt in objects)
    source_classes = [classes_by_name[pt.type] for pt in objects]
    total = len(source_classes)

    # union properties by name across all source classes, mirroring
    # extract_schema.jq's own group_by(.propname) merge behavior
    props_by_name: dict[str, list] = {}
    order: list[str] = []
    for cls in source_classes:
        for prop in cls.properties:
            if prop.propname not in props_by_name:
                props_by_name[prop.propname] = []
                order.append(prop.propname)
            props_by_name[prop.propname].append(prop)

    merged_properties: list[PseudoProperty] = []
    for propname in order:
        props = props_by_name[propname]
        merged_type = _merge_types([p.proptype for p in props], classes, classes_by_name, f"{name}_{propname}")
        missing = len(props) < total
        merged_properties.append(PseudoProperty(propname, merged_type, missing))

    merged_class = PseudoClass(name, merged_properties)
    classes.append(merged_class)
    classes_by_name[name] = merged_class

    for cls in source_classes:
        classes.remove(cls)
        del classes_by_name[cls.name]

    return PseudoPropertyType(PseudoPropertyKind.OBJECT, name, nullable)


def _merge_dicts(
    dicts: list[PseudoPropertyType],
    classes: list[PseudoClass],
    classes_by_name: dict[str, PseudoClass],
    name: str,
) -> PseudoPropertyType:

    nullable = any(pt.nullable for pt in dicts)

    possible_keys: list[str] = []
    for pt in dicts:
        for key in pt.type.possible_keys:
            if key not in possible_keys:
                possible_keys.append(key)

    value_type = _merge_types([pt.type.value_type for pt in dicts], classes, classes_by_name, f"{name}_value")
    kvp = PseudoKeyValuePair("string", value_type, possible_keys)
    return PseudoPropertyType(PseudoPropertyKind.DICT, kvp, nullable)


def _merge_types(
    proptypes: list[PseudoPropertyType],
    classes: list[PseudoClass],
    classes_by_name: dict[str, PseudoClass],
    name: str,
) -> PseudoPropertyType:

    proptypes = _flatten_any(proptypes)

    scalars = [pt for pt in proptypes if pt.kind == PseudoPropertyKind.SCALAR]
    arrays = [pt for pt in proptypes if pt.kind == PseudoPropertyKind.ARRAY]
    objects = [pt for pt in proptypes if pt.kind == PseudoPropertyKind.OBJECT]
    dicts = [pt for pt in proptypes if pt.kind == PseudoPropertyKind.DICT]

    # at most one representative type survives per category (SCALAR is the
    # exception: every distinct scalar type-string survives, deduplicated);
    # only if more than one category (or scalar type) is present do we fall
    # back to ANY, the same as everywhere else in the pipeline
    results: list[PseudoPropertyType] = []
    results.extend(_merge_scalars(scalars))
    if arrays:
        results.append(_merge_arrays(arrays, classes, classes_by_name, name))
    if objects:
        results.append(_merge_objects(objects, classes, classes_by_name, name))
    if dicts:
        results.append(_merge_dicts(dicts, classes, classes_by_name, name))

    if len(results) == 1:
        return results[0]

    nullable = any(pt.nullable for pt in proptypes)
    return PseudoPropertyType(PseudoPropertyKind.ANY, "any", nullable, results)


def _convert_references(proptype: PseudoPropertyType, target_name: str, kvp: PseudoKeyValuePair):
    match proptype.kind:
        case PseudoPropertyKind.OBJECT:
            if proptype.type == target_name:
                proptype.kind = PseudoPropertyKind.DICT
                proptype.type = kvp

        case PseudoPropertyKind.ARRAY:
            _convert_references(proptype.type, target_name, kvp)

        case PseudoPropertyKind.ANY:
            for pt in proptype.possible_types:
                _convert_references(pt, target_name, kvp)

        case PseudoPropertyKind.DICT:
            _convert_references(proptype.type.value_type, target_name, kvp)


def apply_dictionaries(classes: list[PseudoClass], dict_class_names: list[str]):
    classes_by_name = {cls.name: cls for cls in classes}

    missing = [name for name in dict_class_names if name not in classes_by_name]
    if missing:
        raise click.ClickException(f"'dictionaries' references unknown class name(s): {', '.join(missing)}.")

    # classes[0] is always the top-level/root class as schema.to_class() appends
    # nested classes depth-first, then render() reverses the list. Nothing
    # in the tree ever references the root class by name — it's the entry point,
    # not a property value — so there is nowhere to attach a DICT conversion for it;
    # converting it would silently delete the class with no output replacing it.
    root_name = classes[0].name
    if root_name in dict_class_names:
        raise click.ClickException(f"Top-level class '{root_name}' cannot be converted to a dictionary.")

    # Convert deepest-nested targets first, so that a dict-of-dicts (one
    # dict-target class whose value is itself another dict-target class)
    # sees the inner one already collapsed by the time we read the outer
    # one's property types.
    ordered_targets = sorted(
        dict_class_names,
        key=lambda name: classes.index(classes_by_name[name]),
        reverse=True,
    )

    for name in ordered_targets:
        target_cls = classes_by_name[name]

        possible_keys = [prop.propname for prop in target_cls.properties]
        value_type = _merge_types(
            [prop.proptype for prop in target_cls.properties],
            classes,
            classes_by_name,
            f"{name}_value",
        )
        kvp = PseudoKeyValuePair("string", value_type, possible_keys)

        for cls in classes:
            for prop in cls.properties:
                _convert_references(prop.proptype, name, kvp)

        classes.remove(target_cls)
        del classes_by_name[name]
