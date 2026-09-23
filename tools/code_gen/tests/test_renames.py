import click
import pytest

from codegen.models import CodegenContext, PseudoClass, PseudoKeyValuePair, PseudoProperty, PseudoPropertyKind, PseudoPropertyType
from codegen.renames import apply_renames, rename_class_names, rename_property_names

from pathlib import Path


def scalar(t, nullable=False):
    return PseudoPropertyType(PseudoPropertyKind.SCALAR, t, nullable)


def array(inner, nullable=False):
    return PseudoPropertyType(PseudoPropertyKind.ARRAY, inner, nullable)


def obj_ref(name, nullable=False):
    return PseudoPropertyType(PseudoPropertyKind.OBJECT, name, nullable)


def any_type(possible, nullable=False):
    return PseudoPropertyType(PseudoPropertyKind.ANY, "any", nullable, possible)


def dict_type(kvp, nullable=False):
    return PseudoPropertyType(PseudoPropertyKind.DICT, kvp, nullable)


def make_ctx(config=None, classes=None):
    return CodegenContext(
        template_path=Path("dummy.j2"),
        config=config or {},
        debug=False,
        classes=classes or [],
    )


class TestRenamePropertyNames:
    def test_scalar_kind_is_a_noop(self):
        pt = scalar("string")
        rename_property_names(pt, {"string": "renamed"})
        # scalar's own .type is a type-name string, not a class reference —
        # renaming must never touch it
        assert pt.type == "string"

    def test_object_kind_renamed_if_in_map(self):
        pt = obj_ref("OldName")
        rename_property_names(pt, {"OldName": "NewName"})
        assert pt.type == "NewName"

    def test_object_kind_untouched_if_not_in_map(self):
        pt = obj_ref("Unrelated")
        rename_property_names(pt, {"OldName": "NewName"})
        assert pt.type == "Unrelated"

    def test_array_kind_recurses_into_inner_type(self):
        pt = array(obj_ref("OldName"))
        rename_property_names(pt, {"OldName": "NewName"})
        assert pt.type.type == "NewName"

    def test_any_kind_recurses_into_every_possible_type(self):
        pt = any_type([obj_ref("A"), obj_ref("B")])
        rename_property_names(pt, {"A": "A2", "B": "B2"})
        assert pt.possible_types[0].type == "A2"
        assert pt.possible_types[1].type == "B2"

    def test_dict_kind_recurses_into_value_type(self):
        kvp = PseudoKeyValuePair("string", obj_ref("OldName"), ["k1"])
        pt = dict_type(kvp)
        rename_property_names(pt, {"OldName": "NewName"})
        assert pt.type.value_type.type == "NewName"


class TestRenameClassNames:
    def test_class_renamed_when_in_map(self):
        cls = PseudoClass("OldName", [])
        rename_class_names([cls], {"OldName": "NewName"})
        assert cls.name == "NewName"

    def test_class_untouched_when_not_in_map(self):
        cls = PseudoClass("Unrelated", [])
        rename_class_names([cls], {"OldName": "NewName"})
        assert cls.name == "Unrelated"

    def test_rename_to_own_current_name_is_a_noop_not_a_collision(self):
        cls = PseudoClass("Same", [])
        rename_class_names([cls], {"Same": "Same"})
        assert cls.name == "Same"

    def test_collision_with_another_existing_class_raises(self):
        a = PseudoClass("A", [])
        b = PseudoClass("B", [])
        with pytest.raises(click.ClickException, match="Rename collision"):
            rename_class_names([a, b], {"A": "B"})

    def test_property_references_updated_after_class_rename(self):
        target = PseudoClass("Target", [])
        holder = PseudoClass("Holder", [PseudoProperty("field", obj_ref("Target"), False)])
        rename_class_names([target, holder], {"Target": "Renamed"})
        assert target.name == "Renamed"
        assert holder.properties[0].proptype.type == "Renamed"

    def test_root_class_can_be_renamed(self):
        # unlike dictionaries, renames has no special-case guard against
        # renaming the root class — it's a plain name reassignment with no
        # dependency on being referenced elsewhere
        root = PseudoClass("root", [])
        rename_class_names([root], {"root": "Card"})
        assert root.name == "Card"


class TestApplyRenames:
    def test_no_renames_key_is_noop(self):
        cls = PseudoClass("Original", [])
        ctx = make_ctx(config={}, classes=[cls])
        apply_renames(ctx)
        assert cls.name == "Original"

    def test_renames_applied_from_config(self):
        cls = PseudoClass("Original", [])
        ctx = make_ctx(config={"renames": {"Original": "Renamed"}}, classes=[cls])
        apply_renames(ctx)
        assert cls.name == "Renamed"

    def test_invalid_renames_config_raises(self):
        cls = PseudoClass("Original", [])
        ctx = make_ctx(config={"renames": ["not", "a", "dict"]}, classes=[cls])
        with pytest.raises(click.ClickException):
            apply_renames(ctx)
