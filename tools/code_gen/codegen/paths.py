#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path

PROJECT_DIR: Path
CONFIGS_DIR: Path
TEMPLATES_DIR: Path


def configure(project_dir: Path):
    global PROJECT_DIR, CONFIGS_DIR, TEMPLATES_DIR
    PROJECT_DIR = project_dir
    CONFIGS_DIR = project_dir / "configs"
    TEMPLATES_DIR = project_dir / "templates"
