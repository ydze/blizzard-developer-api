from codegen.models import CodegenContext, PseudoPropertyKind
from codegen.schema import to_class, to_type

from pathlib import Path


def make_ctx():
    return CodegenContext(template_path=Path("dummy.j2"), config={}, debug=False)


class TestToTypeSingleScalar:
    def test_single_scalar_type(self):
        ctx = make_ctx()
        result = to_type(ctx, "field", ["string"], "Parent")
        assert result.kind == PseudoPropertyKind.SCALAR
        assert result.type == "string"
        assert result.nullable is False

    def test_single_scalar_with_null_is_nullable(self):
        ctx = make_ctx()
        result = to_type(ctx, "field", ["string", "null"], "Parent")
        assert result.kind == PseudoPropertyKind.SCALAR
        assert result.type == "string"
        assert result.nullable is True

    def test_empty_proptype_list_is_nullable_any(self):
        # proptype == [] means every sample had this field as null
        ctx = make_ctx()
        result = to_type(ctx, "field", [], "Parent")
        assert result.kind == PseudoPropertyKind.ANY
        assert result.type == "any"
        assert result.nullable is True
        assert result.possible_types == []


class TestToTypeSingleArray:
    def test_single_array_type(self):
        ctx = make_ctx()
        result = to_type(ctx, "field", [["integer"]], "Parent")
        assert result.kind == PseudoPropertyKind.ARRAY
        assert result.type.kind == PseudoPropertyKind.SCALAR
        assert result.type.type == "integer"
        assert result.nullable is False

    def test_array_recurses_for_inner_type(self):
        ctx = make_ctx()
        # inner array itself has zero/many types -> nested ANY
        result = to_type(ctx, "field", [["string", "integer"]], "Parent")
        assert result.kind == PseudoPropertyKind.ARRAY
        assert result.type.kind == PseudoPropertyKind.ANY


class TestToTypeSingleObject:
    def test_single_object_type_creates_nested_class(self):
        ctx = make_ctx()
        obj_schema = {"props": [{"propname": "id", "proptype": ["integer"], "missing": False}]}
        result = to_type(ctx, "child", [obj_schema], "Parent")
        assert result.kind == PseudoPropertyKind.OBJECT
        assert result.type == "Parent_child"
        assert len(ctx.classes) == 1
        assert ctx.classes[0].name == "Parent_child"
        assert ctx.classes[0].properties[0].propname == "id"

    def test_nested_object_class_name_uses_parent_and_propname(self):
        ctx = make_ctx()
        obj_schema = {"props": []}
        to_type(ctx, "address", [obj_schema], "User")
        assert ctx.classes[0].name == "User_address"


class TestToTypeAnyKind:
    def test_two_scalar_types_produce_any(self):
        ctx = make_ctx()
        result = to_type(ctx, "field", ["string", "integer"], "Parent")
        assert result.kind == PseudoPropertyKind.ANY
        assert result.type == "any"
        assert len(result.possible_types) == 2
        kinds = {pt.kind for pt in result.possible_types}
        assert kinds == {PseudoPropertyKind.SCALAR}

    def test_scalar_and_array_produce_any(self):
        ctx = make_ctx()
        result = to_type(ctx, "field", ["string", ["integer"]], "Parent")
        assert result.kind == PseudoPropertyKind.ANY
        kinds = {pt.kind for pt in result.possible_types}
        assert kinds == {PseudoPropertyKind.SCALAR, PseudoPropertyKind.ARRAY}

    def test_scalar_and_object_produce_any(self):
        ctx = make_ctx()
        obj_schema = {"props": []}
        result = to_type(ctx, "field", ["string", obj_schema], "Parent")
        assert result.kind == PseudoPropertyKind.ANY
        kinds = {pt.kind for pt in result.possible_types}
        assert kinds == {PseudoPropertyKind.SCALAR, PseudoPropertyKind.OBJECT}

    def test_any_nullable_when_null_present_alongside_multiple_types(self):
        ctx = make_ctx()
        result = to_type(ctx, "field", ["string", "integer", "null"], "Parent")
        assert result.nullable is True


class TestToClass:
    def test_builds_class_with_properties(self):
        ctx = make_ctx()
        properties = [
            {"propname": "id", "proptype": ["integer"], "missing": False},
            {"propname": "name", "proptype": ["string", "null"], "missing": True},
        ]
        cls = to_class(ctx, "MyClass", properties)
        assert cls.name == "MyClass"
        assert len(cls.properties) == 2
        assert cls.properties[0].propname == "id"
        assert cls.properties[0].missing is False
        assert cls.properties[1].propname == "name"
        assert cls.properties[1].missing is True
        assert cls.properties[1].proptype.nullable is True

    def test_empty_properties_list(self):
        ctx = make_ctx()
        cls = to_class(ctx, "Empty", [])
        assert cls.name == "Empty"
        assert cls.properties == []
