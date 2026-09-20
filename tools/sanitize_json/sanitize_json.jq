def sanitize:
  gsub("[\n\r\t]"; "") | gsub("^ +| +$"; "");

walk(if type == "string" then sanitize else . end)