def unique_field_names($group):
  [ $group[] | keys_unsorted[] ] | unique;

def field_values_match($group; $field):
  [ $group[] | select(has($field)) | .[$field] ] as $vals
  | $vals | all(. == $vals[0]);

def field_values_conflict($group):
  unique_field_names($group)
  | map(select(field_values_match($group; .) | not));

def merge_group:
  . as $group
  | field_values_conflict($group) as $conflicts
  | if ($conflicts | length) == 0 then
      add
    else
      error("Record \($key)=\($group[0][$key]) has conflicting values for field(s): \($conflicts | join(", "))")
    end;

if type == "array" and all(.[]; type == "object") then
  if all(.[]; has($key)) then
    group_by(.[$key]) | map(merge_group)
  else
    error("Every object must have the key '\($key)', but at least one is missing it.")
  end
elif type == "object" then
  .
else
  error("Invalid input: expected an array of objects or an object — got: \(type)")
end