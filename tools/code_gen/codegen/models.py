#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum


class PseudoPropertyKind(Enum):
    ANY = "ANY"
    ARRAY = "ARRAY"
    DICT = "DICT"
    ENUM = "ENUM"
    OBJECT = "OBJECT"
    SCALAR = "SCALAR"


@dataclass
class PseudoEnum:
    name: str
    possible_values: list[str] = field(default_factory=list)


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


@dataclass
class PseudoProperty:
    propname: str
    proptype: PseudoPropertyType
    missing: bool


@dataclass
class PseudoClass:
    name: str
    properties: list[PseudoProperty] = field(default_factory=list)
