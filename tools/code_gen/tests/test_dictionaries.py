import click
import pytest

from codegen.dictionaries import (
    apply_dictionaries,
    convert_references,
    flatten_any,
    merge_arrays,
    merge_dicts,
    merge_objects,
    merge_scalars,
    merge_types,
)
from codegen.models import (
    CodegenContext,
    PseudoClass,
    PseudoKeyValuePair,
    PseudoProperty,
    PseudoPropertyKind,
    PseudoPropertyType,
)

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


class TestFlattenAny:
    def test_non_any_types_pass_through_unchanged(self):
        types = [scalar("string"), array(scalar("integer"))]
        assert flatten_any(types) == types

    def test_any_type_expands_into_its_possible_types(self):
        inner = [scalar("string"), scalar("integer")]
        types = [any_type(inner)]
        assert flatten_any(types) == inner

    def test_mix_of_any_and_non_any(self):
        inner = [scalar("string")]
        types = [scalar("boolean"), any_type(inner)]
        result = flatten_any(types)
        assert result == [scalar("boolean"), scalar("string")]


class TestMergeScalars:
    def test_single_type(self):
        result = merge_scalars([scalar("string")])
        assert len(result) == 1
        assert result[0].type == "string"
        assert result[0].nullable is False

    def test_distinct_types_preserved_in_order(self):
        result = merge_scalars([scalar("string"), scalar("integer")])
        assert [r.type for r in result] == ["string", "integer"]

    def test_duplicate_types_deduped_and_nullable_ored(self):
        result = merge_scalars([scalar("string", nullable=False), scalar("string", nullable=True)])
        assert len(result) == 1
        assert result[0].type == "string"
        assert result[0].nullable is True

    def test_empty_list(self):
        assert merge_scalars([]) == []


class TestMergeArrays:
    def test_nullable_true_if_any_source_nullable(self):
        arrays = [array(scalar("integer"), nullable=False), array(scalar("integer"), nullable=True)]
        result = merge_arrays(arrays, [], {}, "name")
        assert result.kind == PseudoPropertyKind.ARRAY
        assert result.nullable is True

    def test_inner_types_merged_recursively(self):
        arrays = [array(scalar("integer")), array(scalar("string"))]
        result = merge_arrays(arrays, [], {}, "name")
        assert result.type.kind == PseudoPropertyKind.ANY
        assert {pt.type for pt in result.type.possible_types} == {"integer", "string"}


class TestMergeObjects:
    def test_unions_properties_across_source_classes(self):
        cls_a = PseudoClass("A", [PseudoProperty("id", scalar("integer"), False)])
        cls_b = PseudoClass("B", [PseudoProperty("name", scalar("string"), False)])
        classes = [cls_a, cls_b]
        classes_by_name = {"A": cls_a, "B": cls_b}
        objects = [obj_ref("A"), obj_ref("B")]

        result = merge_objects(objects, classes, classes_by_name, "Merged")

        assert result.kind == PseudoPropertyKind.OBJECT
        assert result.type == "Merged"
        merged_cls = classes_by_name["Merged"]
        propnames = {p.propname for p in merged_cls.properties}
        assert propnames == {"id", "name"}

    def test_property_missing_true_when_not_present_in_all_sources(self):
        cls_a = PseudoClass("A", [PseudoProperty("id", scalar("integer"), False)])
        cls_b = PseudoClass("B", [PseudoProperty("id", scalar("integer"), False), PseudoProperty("extra", scalar("string"), False)])
        classes = [cls_a, cls_b]
        classes_by_name = {"A": cls_a, "B": cls_b}

        merge_objects([obj_ref("A"), obj_ref("B")], classes, classes_by_name, "Merged")

        merged_cls = classes_by_name["Merged"]
        by_name = {p.propname: p for p in merged_cls.properties}
        assert by_name["id"].missing is False
        assert by_name["extra"].missing is True

    def test_source_classes_removed_after_merge(self):
        cls_a = PseudoClass("A", [])
        cls_b = PseudoClass("B", [])
        classes = [cls_a, cls_b]
        classes_by_name = {"A": cls_a, "B": cls_b}

        merge_objects([obj_ref("A"), obj_ref("B")], classes, classes_by_name, "Merged")

        assert cls_a not in classes
        assert cls_b not in classes
        assert "A" not in classes_by_name
        assert "B" not in classes_by_name
        assert classes_by_name["Merged"] in classes

    def test_nullable_true_if_any_source_nullable(self):
        cls_a = PseudoClass("A", [])
        classes_by_name = {"A": cls_a}
        result = merge_objects([obj_ref("A", nullable=True)], [cls_a], classes_by_name, "Merged")
        assert result.nullable is True


class TestMergeDicts:
    def test_possible_keys_unioned_and_deduped_in_order(self):
        kvp_a = PseudoKeyValuePair("string", scalar("integer"), ["k1", "k2"])
        kvp_b = PseudoKeyValuePair("string", scalar("integer"), ["k2", "k3"])
        result = merge_dicts([dict_type(kvp_a), dict_type(kvp_b)], [], {}, "name")
        assert result.type.possible_keys == ["k1", "k2", "k3"]

    def test_value_types_merged_recursively(self):
        kvp_a = PseudoKeyValuePair("string", scalar("integer"), ["k1"])
        kvp_b = PseudoKeyValuePair("string", scalar("string"), ["k1"])
        result = merge_dicts([dict_type(kvp_a), dict_type(kvp_b)], [], {}, "name")
        assert result.type.value_type.kind == PseudoPropertyKind.ANY

    def test_nullable_true_if_any_source_nullable(self):
        kvp = PseudoKeyValuePair("string", scalar("integer"), ["k1"])
        result = merge_dicts([dict_type(kvp, nullable=True)], [], {}, "name")
        assert result.nullable is True


class TestMergeTypes:
    def test_single_scalar_returns_unwrapped_not_any(self):
        result = merge_types([scalar("string")], [], {}, "name")
        assert result.kind == PseudoPropertyKind.SCALAR

    def test_two_distinct_scalars_wrap_in_any(self):
        result = merge_types([scalar("string"), scalar("integer")], [], {}, "name")
        assert result.kind == PseudoPropertyKind.ANY
        assert len(result.possible_types) == 2

    def test_scalar_and_array_wrap_in_any(self):
        result = merge_types([scalar("string"), array(scalar("integer"))], [], {}, "name")
        assert result.kind == PseudoPropertyKind.ANY
        kinds = {pt.kind for pt in result.possible_types}
        assert kinds == {PseudoPropertyKind.SCALAR, PseudoPropertyKind.ARRAY}

    def test_only_array_present_no_scalars(self):
        result = merge_types([array(scalar("integer"))], [], {}, "name")
        assert result.kind == PseudoPropertyKind.ARRAY

    def test_only_dict_present(self):
        kvp = PseudoKeyValuePair("string", scalar("integer"), ["k1"])
        result = merge_types([dict_type(kvp)], [], {}, "name")
        assert result.kind == PseudoPropertyKind.DICT

    def test_object_present_dispatches_through_merge_objects(self):
        cls_a = PseudoClass("A", [PseudoProperty("id", scalar("integer"), False)])
        classes = [cls_a]
        classes_by_name = {"A": cls_a}
        result = merge_types([obj_ref("A")], classes, classes_by_name, "name")
        assert result.kind == PseudoPropertyKind.OBJECT
        assert result.type == "name"
        assert classes_by_name["name"].properties[0].propname == "id"

    def test_flattens_any_before_categorizing(self):
        # an ANY wrapping two scalars should flatten and merge into ONE
        # scalar-only result, not remain wrapped in a redundant outer ANY
        nested = any_type([scalar("string"), scalar("string")])
        result = merge_types([nested], [], {}, "name")
        assert result.kind == PseudoPropertyKind.SCALAR
        assert result.type == "string"

    def test_nullable_true_if_any_input_nullable(self):
        result = merge_types([scalar("string"), scalar("integer", nullable=True)], [], {}, "name")
        assert result.nullable is True


class TestConvertReferences:
    def test_object_matching_target_becomes_dict(self):
        kvp = PseudoKeyValuePair("string", scalar("integer"), ["k1"])
        pt = obj_ref("Target")
        convert_references(pt, "Target", kvp)
        assert pt.kind == PseudoPropertyKind.DICT
        assert pt.type == kvp

    def test_object_not_matching_target_untouched(self):
        kvp = PseudoKeyValuePair("string", scalar("integer"), ["k1"])
        pt = obj_ref("Other")
        convert_references(pt, "Target", kvp)
        assert pt.kind == PseudoPropertyKind.OBJECT
        assert pt.type == "Other"

    def test_recurses_into_array(self):
        kvp = PseudoKeyValuePair("string", scalar("integer"), ["k1"])
        pt = array(obj_ref("Target"))
        convert_references(pt, "Target", kvp)
        assert pt.type.kind == PseudoPropertyKind.DICT

    def test_recurses_into_any_possible_types(self):
        kvp = PseudoKeyValuePair("string", scalar("integer"), ["k1"])
        pt = any_type([scalar("string"), obj_ref("Target")])
        convert_references(pt, "Target", kvp)
        assert pt.possible_types[1].kind == PseudoPropertyKind.DICT

    def test_recurses_into_dict_value_type(self):
        inner_kvp = PseudoKeyValuePair("string", obj_ref("Target"), ["k1"])
        outer_kvp = PseudoKeyValuePair("string", scalar("integer"), ["k1"])
        pt = dict_type(inner_kvp)
        convert_references(pt, "Target", outer_kvp)
        assert pt.type.value_type.kind == PseudoPropertyKind.DICT


class TestApplyDictionaries:
    def test_no_dictionaries_key_is_noop(self):
        root = PseudoClass("root", [])
        ctx = make_ctx(config={}, classes=[root])
        apply_dictionaries(ctx)
        assert ctx.classes == [root]

    def test_unknown_class_name_raises(self):
        root = PseudoClass("root", [])
        ctx = make_ctx(config={"dictionaries": ["nonexistent"]}, classes=[root])
        with pytest.raises(click.ClickException, match="unknown class name"):
            apply_dictionaries(ctx)

    def test_root_class_cannot_be_dictionary(self):
        root = PseudoClass("root", [])
        ctx = make_ctx(config={"dictionaries": ["root"]}, classes=[root])
        with pytest.raises(click.ClickException, match="cannot be converted to a dictionary"):
            apply_dictionaries(ctx)

    def test_single_target_converted_correctly(self):
        target = PseudoClass("root_obj", [PseudoProperty("key1", scalar("integer"), False)])
        root = PseudoClass("root", [PseudoProperty("obj", obj_ref("root_obj"), False)])
        ctx = make_ctx(config={"dictionaries": ["root_obj"]}, classes=[root, target])

        apply_dictionaries(ctx)

        assert root.properties[0].proptype.kind == PseudoPropertyKind.DICT
        assert root.properties[0].proptype.type.possible_keys == ["key1"]
        assert target not in ctx.classes

    def test_deepest_nested_target_converted_first(self):
        # a dict-of-dicts: the inner target must be collapsed before the
        # outer one reads its property types, or the outer conversion
        # would see a stale OBJECT reference instead of a DICT
        inner = PseudoClass("root_obj_value", [PseudoProperty("x", scalar("integer"), False)])
        outer = PseudoClass("root_obj", [PseudoProperty("inner_key", obj_ref("root_obj_value"), False)])
        root = PseudoClass("root", [PseudoProperty("obj", obj_ref("root_obj"), False)])
        ctx = make_ctx(
            config={"dictionaries": ["root_obj", "root_obj_value"]},
            classes=[root, outer, inner],
        )

        apply_dictionaries(ctx)

        outer_dict = root.properties[0].proptype
        assert outer_dict.kind == PseudoPropertyKind.DICT
        inner_result = outer_dict.type.value_type
        assert inner_result.kind == PseudoPropertyKind.DICT
        assert inner_result.type.possible_keys == ["x"]
