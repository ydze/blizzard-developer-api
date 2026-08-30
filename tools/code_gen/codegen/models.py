#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum


class PseudoPropertyKind(Enum):
    ANY = "ANY"
    ARRAY = "ARRAY"
    DICT = "DICT"
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
