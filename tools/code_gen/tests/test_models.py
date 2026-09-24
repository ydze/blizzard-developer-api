import pytest

from codegen.models import PseudoKeyValuePair, PseudoPropertyKind, PseudoPropertyType, as_typename, as_proptype, as_kvp


def scalar(t):
    return PseudoPropertyType(PseudoPropertyKind.SCALAR, t, False)


class TestAsTypeName:
    def test_string_passes_through(self):
        assert as_typename("MyClass") == "MyClass"

    def test_non_string_raises_type_error(self):
        with pytest.raises(TypeError, match="Expected a type-name string"):
            as_typename(scalar("integer"))


class TestAsProptype:
    def test_proptype_passes_through(self):
        pt = scalar("integer")
        assert as_proptype(pt) is pt

    def test_non_proptype_raises_type_error(self):
        with pytest.raises(TypeError, match="Expected a PseudoPropertyType"):
            as_proptype("not a proptype")


class TestAsKvp:
    def test_kvp_passes_through(self):
        kvp = PseudoKeyValuePair("string", scalar("integer"), ["k1"])
        assert as_kvp(kvp) is kvp

    def test_non_kvp_raises_type_error(self):
        with pytest.raises(TypeError, match="Expected a PseudoKeyValuePair"):
            as_kvp("not a kvp")
