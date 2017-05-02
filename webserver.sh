#!/bin/bash
PREFIX="./public" # directory of hosted files
CONSOLE=3 # console output gets file descriptor 3
if test -z "${NCAT_LOCAL_PORT}"; then # => not launched by ncat => launch ncat
  port="$1"; if test -z "$port"; then port="3000"; fi
  eval "exec $CONSOLE>&1" # send console output to stdout
  ncat -kl "$port" -c "$0" # launch netcat
  exit 1 # this line is reached if ncat terminates, but usually the bash script terminates before
fi
strip_margin(){ sed -r "s|^ +||"; }; convert_newlines(){ sed -r "s|$|\r|"; }
filename=""
while read untrimmed_line; do
  line=`echo "${untrimmed_line}" | tr -d "\r\n"` # remove some trailing white spaces
  if test -z "$filename"; then # => filename unknown => this must be the request's first line
    first=`echo "$line" | mawk '{ print $1 }'` # extract the HTTP method (first field)
    if test "$first" = "GET"; then # => method is GET
      echo "$line" >&$CONSOLE
      path=`echo "$line" | mawk '{ print $2 }'` # extract the filename (second field)
      if test "$path" = "/"; then path="/index.html"; fi
      filename="$PREFIX$path" # e.g. "/public/index.html"
    fi
  fi
  if test -z "$line"; then # => empty line encountered => end of header reached
    echo "requested filename: $filename" >&$CONSOLE
    if test -e "$filename"; then
      filesize=`stat -Lc "%s" "$filename"`
      echo "file size: $filesize" >&$CONSOLE
      header=`echo "HTTP/1.1 200 OK
                    Cache-Control: no-cache, no-store, must-revalidate
                    Connection: close
                    Content-Length: $filesize
                    " | strip_margin | convert_newlines`
      echo "$header" && cat "$filename"
      echo "file \"$filename\" sent" >&$CONSOLE
    else
      echo "not found" >&$CONSOLE
      header=`echo "HTTP/1.1 404 Not Found
                    Cache-Control: no-cache, no-store, must-revalidate
                    Connection: close
                    Content-Length: 0
                    " | strip_margin | convert_newlines`
      echo "$header"
    fi
    filename=""
    echo >&$CONSOLE # print newline
  fi
done
