def merge:
  if length == 0 then
    []
  elif all(.[]; type == "string") then
    unique
  else
    ( [ .[] | select(type == "string") ] | unique ) as $sca_desc |
    ( [ .[] | select(type == "array") ] ) as $arr_desc |
    ( [ .[] | select(type == "object" and has("props")) ] ) as $obj_desc |

    $sca_desc

    + if ( $arr_desc | length ) == 0 then
        []
      else
        [ ( $arr_desc | flatten(1) | if length == 0 then [] else merge end ) ]
      end

    + if ( $obj_desc | length ) == 0 then
        []
      else
        # Step 1: capture the $total number of described objects.
        ( $obj_desc | length ) as $total |

        [
          # Step 2: group object's properties by property name.
          [ $obj_desc[] | .props[] ]
          | group_by(.propname)

          # Step 3: iterate each group — one group per unique property name.
          | {
              props: [ .[]
                | {
                    propname: .[0].propname,
                    proptype: ( [ .[].proptype[] ] | merge ),

                    # Step 4: mark property as missing/nullable if number of {key, value} pairs in the group is less than $total objects.
                    nullable: ( length < $total )
                  }
              ]
            }
        ]
      end
  end;

def describe:
  if type == "array" then
    if length == 0 then
      []
    else
      [ .[] | describe ]
    end
  elif type == "object" then
    if length == 0 then
      { props: [] }
    else
      {
        props: [
          [ to_entries[] ]
          | group_by(.key)
          | .[]
            | {
                propname: .[0].key,
                proptype: [ .[].value | describe ]
              }
        ]
      }
    end
  else
    type
  end;

def indent(n): reduce range(n) as $i (""; . + "  ");

def format:
  ( .depth ) as $curr_lvl |
  ( .depth + 1 ) as $next_lvl |
  ( indent($curr_lvl) ) as $curr_indent |
  ( indent($next_lvl) ) as $next_indent |

  ( [ .data[] | select(type == "string" and . != "null") ] ) as $sca_types |
  ( [ .data[] | select(type == "array") ] ) as $arr_types |
  ( [ .data[] | select(type == "object" and has("props")) ] ) as $obj_types |

  ( any(.data[]; . == "null") ) as $nullable |

  ( [ $sca_types[] ]

  + [ $arr_types[] | { depth: $next_lvl, data: . } | format | "[\n\($next_indent)\(.)\n\($curr_indent)]" ]

  + [ $obj_types[]
      | [ .props[]
          | "\($next_indent)\(.propname): \(.proptype | { depth: $next_lvl, data: . } | format)\(if .nullable then "?" else "" end)"
        ]
        | join(",\n")
        | "{\n\(.)\n\($curr_indent)}"
    ]

  ) | [ .[] | . + if $nullable then "?" else "" end ] | join(",\n\($curr_indent)");

if type == "array" then
  [ .[] | describe ] | merge
elif type == "object" then
  [ . | describe ] | merge[0]
else
  . | describe
end

# { depth: 0, data: [ .[] ] | build_schema } | format