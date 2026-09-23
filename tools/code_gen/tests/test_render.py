import click
import pytest

from codegen import paths
from codegen.models import CodegenContext
from codegen.render import apply_config, normalize_schema, render

from pathlib import Path


@pytest.fixture(autouse=True)
def configure_paths():
    # print_debug() reads paths.TEMPLATES_DIR to locate debug.j2; several
    # tests exercise the debug=True path, so this must be configured before
    # they run, mirroring what the real CLI entry point does at startup.
    paths.configure(Path(__file__).resolve().parents[1])


def make_ctx(template_path, config=None, debug=False, classes=None):
    return CodegenContext(
        template_path=template_path,
        config=config or {},
        debug=debug,
        classes=classes or [],
    )


MINIMAL_TEMPLATE = "{% for cls in classes %}class {{ cls.name }}\n{% endfor %}"


class TestNormalizeSchema:
    def test_single_element_list_unwraps(self):
        schema = {"props": [{"propname": "id", "proptype": ["integer"], "missing": False}]}
        assert normalize_schema([schema]) == schema

    def test_dict_with_props_passes_through(self):
        schema = {"props": []}
        assert normalize_schema(schema) == schema

    def test_multi_element_list_raises(self):
        with pytest.raises(click.ClickException):
            normalize_schema([{"props": []}, {"props": []}])

    def test_empty_list_raises(self):
        with pytest.raises(click.ClickException):
            normalize_schema([])

    def test_dict_without_props_raises(self):
        with pytest.raises(click.ClickException):
            normalize_schema({"not_props": []})

    def test_scalar_schema_raises(self):
        with pytest.raises(click.ClickException):
            normalize_schema("string")


class TestApplyConfig:
    def test_both_dictionaries_and_renames_applied_together(self, tmp_path):
        template_path = tmp_path / "t.j2"
        template_path.write_text(MINIMAL_TEMPLATE)
        schema = {
            "props": [
                {
                    "propname": "obj",
                    "proptype": [{"props": [{"propname": "key1", "proptype": ["integer"], "missing": False}]}],
                    "missing": False,
                }
            ]
        }
        ctx = make_ctx(template_path, config={"dictionaries": ["root_obj"], "renames": {"root": "Card"}})
        result = render(ctx, [schema])

        # root was renamed by apply_renames
        assert "class Card" in result
        assert "class root" not in result

        # root_obj was converted to a DICT by apply_dictionaries, and the
        # now-unused root_obj class itself was removed from ctx.classes
        from codegen.models import PseudoPropertyKind

        root_cls = next(cls for cls in ctx.classes if cls.name == "Card")
        obj_prop = next(p for p in root_cls.properties if p.propname == "obj")
        assert obj_prop.proptype.kind == PseudoPropertyKind.DICT
        assert obj_prop.proptype.type.possible_keys == ["key1"]
        assert all(cls.name != "root_obj" for cls in ctx.classes)


class TestRenderEndToEnd:
    def test_root_class_name_is_hardcoded_root_without_config(self, tmp_path):
        template_path = tmp_path / "t.j2"
        template_path.write_text(MINIMAL_TEMPLATE)
        schema = {"props": []}
        ctx = make_ctx(template_path)
        result = render(ctx, [schema])
        assert result.strip() == "class root"

    def test_nested_classes_appended_before_root_after_reversal(self, tmp_path):
        template_path = tmp_path / "t.j2"
        template_path.write_text(MINIMAL_TEMPLATE)
        schema = {
            "props": [
                {
                    "propname": "child",
                    "proptype": [{"props": []}],
                    "missing": False,
                }
            ]
        }
        ctx = make_ctx(template_path)
        render(ctx, [schema])
        # nested classes are appended depth-first, then reversed so the
        # root ends up first in the final list
        assert ctx.classes[0].name == "root"
        assert ctx.classes[1].name == "root_child"

    def test_debug_false_prints_nothing(self, tmp_path, capsys):
        template_path = tmp_path / "t.j2"
        template_path.write_text(MINIMAL_TEMPLATE)
        ctx = make_ctx(template_path, debug=False)
        render(ctx, [{"props": []}])
        captured = capsys.readouterr()
        assert "Class Schematics" not in captured.out

    def test_debug_true_prints_schematics(self, tmp_path, capsys):
        template_path = tmp_path / "t.j2"
        template_path.write_text(MINIMAL_TEMPLATE)
        ctx = make_ctx(template_path, debug=True)
        render(ctx, [{"props": []}])
        captured = capsys.readouterr()
        assert "Class Schematics" in captured.out
