def sanitize:
    gsub("[\n\r\t]"; " ")
  | gsub(" {2,}"; " ")
  | gsub("^ +| +$"; "");

walk(if type == "string" then sanitize else . end)