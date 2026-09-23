from codegen import paths
from codegen.debug import print_debug
from codegen.models import CodegenContext, PseudoClass, PseudoProperty, PseudoPropertyKind, PseudoPropertyType

from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def configure_paths():
    paths.configure(Path(__file__).resolve().parents[1])


def make_ctx(debug, classes):
    return CodegenContext(template_path=Path("dummy.j2"), config={}, debug=debug, classes=classes)


class TestPrintDebug:
    def test_debug_false_prints_nothing(self, capsys):
        ctx = make_ctx(debug=False, classes=[PseudoClass("root", [])])
        print_debug(ctx)
        assert capsys.readouterr().out == ""

    def test_debug_true_prints_class_names(self, capsys):
        cls = PseudoClass("root", [PseudoProperty("id", PseudoPropertyType(PseudoPropertyKind.SCALAR, "integer", False), False)])
        ctx = make_ctx(debug=True, classes=[cls])
        print_debug(ctx)
        out = capsys.readouterr().out
        assert "root" in out

    def test_enum_kind_serialized_via_its_value_not_raise(self, capsys):
        # json.dumps can't serialize a PseudoPropertyKind enum member directly —
        # print_debug supplies a default= handler for this, and this test would
        # fail with a raised TypeError if that handler were ever removed or broken
        cls = PseudoClass("root", [PseudoProperty("id", PseudoPropertyType(PseudoPropertyKind.SCALAR, "integer", False), False)])
        ctx = make_ctx(debug=True, classes=[cls])
        print_debug(ctx)
        out = capsys.readouterr().out
        assert "SCALAR" in out

    def test_multiple_classes_all_printed(self, capsys):
        classes = [PseudoClass("root", []), PseudoClass("root_child", [])]
        ctx = make_ctx(debug=True, classes=classes)
        print_debug(ctx)
        out = capsys.readouterr().out
        assert "root" in out
        assert "root_child" in out
