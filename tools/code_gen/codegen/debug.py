#!/usr/bin/env python3

from __future__ import annotations

from codegen.models import CodegenContext
from codegen import paths

from dataclasses import asdict
from enum import Enum
from jinja2 import Environment, FileSystemLoader

import json


def print_debug(ctx: CodegenContext):
    if ctx.debug:
        debug_template_path = paths.TEMPLATES_DIR / "debug.j2"
        env = Environment(
            loader=FileSystemLoader(str(debug_template_path.parent)),
            lstrip_blocks=True,
            trim_blocks=True,
        )

        debug_classes = [
            {
                "name": cls.name,
                "json_str": json.dumps(
                    asdict(cls),
                    indent=2,
                    default=lambda element: element.value if isinstance(element, Enum) else str(element),
                ),
            }
            for cls in ctx.classes
        ]

        tmpl = env.get_template(debug_template_path.name)
        result = tmpl.render(classes=debug_classes)
        print(result)
