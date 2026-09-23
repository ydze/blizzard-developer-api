import json

from click.testing import CliRunner

import render as cli

MINIMAL_TEMPLATE = "{% for cls in classes %}class {{ cls.name }}\n{% endfor %}"
SIMPLE_SCHEMA = {"props": [{"propname": "id", "proptype": ["integer"], "missing": False}]}


def write(path, content):
    if isinstance(content, (dict, list)):
        path.write_text(json.dumps(content))
    else:
        path.write_text(content)
    return str(path)


class TestRequiredOptions:
    def test_missing_template_fails(self, tmp_path):
        input_path = write(tmp_path / "in.json", [SIMPLE_SCHEMA])
        result = CliRunner().invoke(cli.main, ["--input", input_path])
        assert result.exit_code != 0
        assert "--template" in result.output

    def test_missing_input_fails(self, tmp_path):
        template_path = write(tmp_path / "t.j2", MINIMAL_TEMPLATE)
        result = CliRunner().invoke(cli.main, ["--template", template_path])
        assert result.exit_code != 0
        assert "--input" in result.output

    def test_nonexistent_template_path_fails(self, tmp_path):
        input_path = write(tmp_path / "in.json", [SIMPLE_SCHEMA])
        result = CliRunner().invoke(cli.main, ["--template", str(tmp_path / "missing.j2"), "--input", input_path])
        assert result.exit_code != 0

    def test_nonexistent_input_path_fails(self, tmp_path):
        template_path = write(tmp_path / "t.j2", MINIMAL_TEMPLATE)
        result = CliRunner().invoke(cli.main, ["--template", template_path, "--input", str(tmp_path / "missing.json")])
        assert result.exit_code != 0


class TestBasicInvocation:
    def test_valid_invocation_prints_to_stdout(self, tmp_path):
        template_path = write(tmp_path / "t.j2", MINIMAL_TEMPLATE)
        input_path = write(tmp_path / "in.json", [SIMPLE_SCHEMA])
        result = CliRunner().invoke(cli.main, ["--template", template_path, "--input", input_path])
        assert result.exit_code == 0
        assert "class root" in result.output

    def test_invalid_input_json_fails(self, tmp_path):
        template_path = write(tmp_path / "t.j2", MINIMAL_TEMPLATE)
        input_path = tmp_path / "in.json"
        input_path.write_text("{not valid json")
        result = CliRunner().invoke(cli.main, ["--template", template_path, "--input", str(input_path)])
        assert result.exit_code != 0


class TestOutputOption:
    def test_output_to_file_instead_of_stdout(self, tmp_path):
        template_path = write(tmp_path / "t.j2", MINIMAL_TEMPLATE)
        input_path = write(tmp_path / "in.json", [SIMPLE_SCHEMA])
        output_path = tmp_path / "out.txt"
        result = CliRunner().invoke(cli.main, ["--template", template_path, "--input", input_path, "--output", str(output_path)])
        assert result.exit_code == 0
        assert "class root" not in result.output
        assert "Saved" in result.output
        assert "class root" in output_path.read_text()


class TestConfigOption:
    def test_valid_config_applied(self, tmp_path):
        template_path = write(tmp_path / "t.j2", MINIMAL_TEMPLATE)
        input_path = write(tmp_path / "in.json", [SIMPLE_SCHEMA])
        config_path = write(tmp_path / "cfg.json", {"renames": {"root": "Card"}})
        result = CliRunner().invoke(cli.main, ["--template", template_path, "--input", input_path, "--config", config_path])
        assert result.exit_code == 0
        assert "class Card" in result.output

    def test_config_not_a_json_object_fails(self, tmp_path):
        template_path = write(tmp_path / "t.j2", MINIMAL_TEMPLATE)
        input_path = write(tmp_path / "in.json", [SIMPLE_SCHEMA])
        config_path = write(tmp_path / "cfg.json", ["not", "an", "object"])
        result = CliRunner().invoke(cli.main, ["--template", template_path, "--input", input_path, "--config", config_path])
        assert result.exit_code != 0


class TestDebugOption:
    def test_debug_flag_includes_schematics(self, tmp_path):
        template_path = write(tmp_path / "t.j2", MINIMAL_TEMPLATE)
        input_path = write(tmp_path / "in.json", [SIMPLE_SCHEMA])
        result = CliRunner().invoke(cli.main, ["--template", template_path, "--input", input_path, "--debug"])
        assert result.exit_code == 0
        assert "Class Schematics" in result.output

    def test_no_debug_flag_omits_schematics(self, tmp_path):
        template_path = write(tmp_path / "t.j2", MINIMAL_TEMPLATE)
        input_path = write(tmp_path / "in.json", [SIMPLE_SCHEMA])
        result = CliRunner().invoke(cli.main, ["--template", template_path, "--input", input_path])
        assert result.exit_code == 0
        assert "Class Schematics" not in result.output
