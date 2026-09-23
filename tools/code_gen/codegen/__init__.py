"""
codegen — turns an extract_schema.jq-derived JSON schema into typed source
code via Jinja2 templates.

Supports converting dictionary-shaped objects into Dictionary<K, V> properties
and renaming generated class names, both configured via an optional JSON config
file passed on the command line.
"""

__version__ = "0.1.0"
__author__ = "Yuriy Dzera"
