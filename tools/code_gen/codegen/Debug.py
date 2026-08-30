#!/usr/bin/env python3

from __future__ import annotations

from codegen.Models import PseudoClass
from codegen import Paths

from dataclasses import asdict
from enum import Enum
from jinja2 import Environment, FileSystemLoader

import json


def print_debug(classes: list[PseudoClass]):
    debug_template_path = Paths.TEMPLATES_DIR / "debug.j2"
    env = Environment(
        loader=FileSystemLoader(str(debug_template_path.parent)),
        lstrip_blocks=True,
        trim_blocks=True,
    )

    tmpl = env.get_template(debug_template_path.name)

    debug_classes = [
        {
            "name": cls.name,
            "json_str": json.dumps(
                asdict(cls),
                indent=2,
                default=lambda o: o.value if isinstance(o, Enum) else str(o),
            ),
        }
        for cls in classes
    ]

    print(tmpl.render(classes=debug_classes))
