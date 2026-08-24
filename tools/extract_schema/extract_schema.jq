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
                    missing: ( length < $total )
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
  # Step 1: set indentation levels
  ( .depth ) as $curr_lvl |
  ( .depth + 1 ) as $next_lvl |
  ( .depth + 2 ) as $deep_lvl |
  ( indent($curr_lvl) ) as $curr_indent |
  ( indent($next_lvl) ) as $next_indent |
  ( indent($deep_lvl) ) as $deep_indent |

  # Step 2: group types by category
  ( [ .data[] | select(type == "string" and . != "null") ] ) as $sca_types |
  ( [ .data[] | select(type == "array") ] ) as $arr_types |
  ( [ .data[] | select(type == "object" and has("props")) ] ) as $obj_types |

  # Step 3: if 'null' appears alongside other types, mark them as nullable
  ( ( .data | length ) > 1 and any(.data[]; . == "null") ) as $nullable |

  # Step 4: (fallback), display 'null' explicitly when it is the only type
  ( if ( .data | length ) == 1 and .data[0] == "null" then ["null"] else $sca_types end ) as $sca_types |

  ( [ $sca_types[] ]

  + [ $arr_types[]
      | if length == 0 then
          "[]"
        else
          # Step 5: if array contains only one scalar type, display it without indentation
          ( map(select(. != "null")) | ( length == 1 and ( .[0] | type == "string" ) ) ) as $single
          | { depth: $next_lvl, data: . }
          | format
          | if $single then
              "[ \(.) ]"
            else
              "[\n\($next_indent)\(.)\n\($curr_indent)]"
            end
        end
    ]

  + [ $obj_types[]
      | if ( .props | length ) == 0 then
          "{}"
        else
          [ .props[]
            | ( .proptype | map(select(. != "null")) | length > 1 ) as $many
            # Step 6: apply $null_mark only if 'null' is not one of the missing/nullable property types
            | ( if .missing and ( any(.proptype[]; . == "null") | not ) then "?" else "" end ) as $null_mark
            | ( if $many then $deep_lvl else $next_lvl end ) as $lvl
            | ( if $many then "\n\($deep_indent)" else "" end ) as $ind
            | "\($next_indent)\(.propname): \( { depth: $lvl, data: .proptype } | format | "\($ind)\(.)\($null_mark)" )"
          ]
          | join(",\n")
          | "{\n\(.)\n\($curr_indent)}"
        end
    ]

  ) | [ .[] | . + if $nullable then "?" else "" end ] | join(",\n\($curr_indent)");

if type == "array" then
  [ .[] | describe ] | merge
elif type == "object" then
  [ . | describe ] | merge[0]
else
  . | describe
end
| if $format == "default" then
    { depth: 0, data: [ . ] } | format
  elif $format == "raw" then
    .
  else
    error("Unknown format '\($format)'. Use 'default' or 'raw'.")
  end