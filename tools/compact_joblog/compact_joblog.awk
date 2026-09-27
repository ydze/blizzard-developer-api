#!/usr/bin/awk -f

# Reads a GNU parallel --joblog file and prints only the jobs whose latest
# run failed (non-zero Exitval or Signal), in Seq order, maintaining the header.
# Prints nothing at all when no job failed.

BEGIN { FS = "\t" }

# Line 1 is the column header, not a job — keep it aside.
FNR == 1 { header = $0; next }

# GNU parallel appends every job it runs to the --joblog file;
# when compacting the job log, keep only the most recent result.
{
    latest[$1] = $0
    failed[$1] = ($7 != 0 || $8 != 0)
    if ($1 > max_seq) max_seq = $1
}

END {
    for (seq = 1; seq <= max_seq; seq++) {
        if (seq in failed && failed[seq]) {
            if (count++ == 0) print header
            print latest[seq]
        }
    }
}