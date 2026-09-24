#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path


class PseudoPropertyKind(Enum):
    ANY = "ANY"
    ARRAY = "ARRAY"
    DICT = "DICT"
    ENUM = "ENUM"
    OBJECT = "OBJECT"
    SCALAR = "SCALAR"


@dataclass
class PseudoKeyValuePair:
    key_type: str
    value_type: "PseudoPropertyType"
    possible_keys: list[str] = field(default_factory=list)


@dataclass
class PseudoPropertyType:
    kind: PseudoPropertyKind
    type: str | "PseudoPropertyType" | PseudoKeyValuePair
    nullable: bool
    possible_types: list["PseudoPropertyType"] = field(default_factory=list)


# PseudoPropertyType.type is a union whose actual variant is determined by
# the separate `kind` field at runtime (e.g. kind == DICT implies type is a
# PseudoKeyValuePair) — a relationship mypy can't verify across two separate
# fields on its own. These narrow the union explicitly at call sites where
# the caller already knows which variant applies.
def as_typename(value: str | PseudoPropertyType | PseudoKeyValuePair) -> str:
    if not isinstance(value, str):
        raise TypeError(f"Expected a type-name string, got {type(value).__name__}.")
    return value


def as_proptype(value: str | PseudoPropertyType | PseudoKeyValuePair) -> PseudoPropertyType:
    if not isinstance(value, PseudoPropertyType):
        raise TypeError(f"Expected a PseudoPropertyType, got {type(value).__name__}.")
    return value


def as_kvp(value: str | PseudoPropertyType | PseudoKeyValuePair) -> PseudoKeyValuePair:
    if not isinstance(value, PseudoKeyValuePair):
        raise TypeError(f"Expected a PseudoKeyValuePair, got {type(value).__name__}.")
    return value


@dataclass
class PseudoProperty:
    propname: str
    proptype: PseudoPropertyType
    missing: bool


@dataclass
class PseudoClass:
    name: str
    properties: list[PseudoProperty] = field(default_factory=list)


@dataclass
class CodegenContext:
    template_path: Path
    config: dict
    debug: bool
    classes: list[PseudoClass] = field(default_factory=list)
