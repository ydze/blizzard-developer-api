def is_valid_value:
  type == "string" and test("^[a-zA-Z_][a-zA-Z0-9_]*$");


def extract($container):
  if ( $container | length ) == 0 then
    .
  elif type == "array" then
    map(extract($container)) | map(select(. != null)) | flatten(1)
  elif type == "object" and has($container[0]) then
    .[$container[0]] | extract($container[1:])
  else
    null
  end;


def validate($container; $field):
  if . == null then
    error("Input object does not contain path '/\($container | join("/"))'")
  elif (type == "array" and all(.[]; type == "object")) | not then
    error("Input object schema is not uniform: not every element at path '/\($container | join("/"))' is an object")
  elif (all(.[]; has($field))) | not then
    error("Input object is malformed: not every object at path '/\($container | join("/"))' has a field '\($field)'")
  else
    .
  end;


  ( $path[:-1] ) as $container
| ( $path[-1] ) as $field

| extract($container)
| validate($container; $field)

| ( map(.[$field]) | unique ) as $values
| ( $values | map(select(is_valid_value | not)) | unique ) as $invalid_values
| ( $invalid_values | length == 0 ) as $is_valid
| ( $path | join("_") ) as $key

| {
    is_valid: $is_valid,
    key: $key,
    values: $values,
    invalid_values: $invalid_values
  }