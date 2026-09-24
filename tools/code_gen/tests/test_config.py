import json

import click
import pytest

from codegen.config import load_config, validate_dictionaries, validate_renames


class TestLoadConfig:
    def test_none_path_returns_empty_dict(self):
        assert load_config(None) == {}

    def test_valid_json_object_is_loaded(self, tmp_path):
        path = tmp_path / "config.json"
        path.write_text(json.dumps({"renames": {"a": "b"}}))
        assert load_config(str(path)) == {"renames": {"a": "b"}}

    def test_non_object_json_raises(self, tmp_path):
        path = tmp_path / "config.json"
        path.write_text(json.dumps(["not", "an", "object"]))
        with pytest.raises(click.ClickException):
            load_config(str(path))


class TestValidateRenames:
    def test_valid_string_to_string_dict_passes(self):
        renames = {"old_name": "NewName"}
        assert validate_renames(renames) == renames

    def test_empty_dict_passes(self):
        assert validate_renames({}) == {}

    def test_non_dict_raises(self):
        with pytest.raises(click.ClickException):
            validate_renames(["not", "a", "dict"])

    def test_non_string_value_raises(self):
        with pytest.raises(TypeError, match="expected string or bytes-like object, got 'int'"):
            validate_renames({"a": 123})

    def test_non_valid_string_value_raises(self):
        with pytest.raises(click.ClickException, match="Class name must start with a letter and contain only letters, numbers and underscores."):
            validate_renames({"a": "123"})

    def test_non_string_key_raises(self):
        # JSON object keys are always strings once parsed, but the function
        # should still be defensive against a non-string key reaching it
        # from any other caller.
        with pytest.raises(click.ClickException):
            validate_renames({1: "b"})


class TestValidateDictionaries:
    def test_valid_string_list_passes(self):
        names = ["class_a", "class_b"]
        assert validate_dictionaries(names) == names

    def test_empty_list_passes(self):
        assert validate_dictionaries([]) == []

    def test_non_list_raises(self):
        with pytest.raises(click.ClickException):
            validate_dictionaries({"not": "a list"})

    def test_non_string_element_raises(self):
        with pytest.raises(click.ClickException):
            validate_dictionaries(["ok", 123])
