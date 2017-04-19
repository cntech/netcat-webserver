#!/bin/bash
PREFIX="./public"
function strip_margin {
  sed -r "s|^ +||"
}
function convert_newlines {
  sed -r "s|$|\r|"
}
coproc nc -k -l -p 3000 # launch netcat
input="${COPROC[0]}" # get "read" file descriptor (netcat's stdout)
output="${COPROC[1]}" # get "write" file descriptor (netcat's stdin)
filename=""
while read untrimmed_line; do
  line=`echo "${untrimmed_line}" | tr -d "\r\n"` # remove some trailing white spaces
  if test -z "$filename"; then # => filename unknown => this must be the request's first line
    first=`echo "$line" | mawk '{ print $1 }'` # extract the HTTP method (first field)
    if test "$first" = "GET"; then # => method is GET
      echo "$line"
      path=`echo "$line" | mawk '{ print $2 }'` # extract the filename (second field)
      if test "$path" = "/"; then path="/index.html"; fi
      filename="$PREFIX$path" # e.g. "/public/index.html"
    fi
  fi
  if test -z "$line"; then # => empty line encountered => end of header reached
    echo "requested filename: $filename"
    if test -e "$filename"; then
      filesize=`stat -c "%s" "$filename"`
      echo "file size: $filesize"
      # Content-Type: text/html; charset=UTF-8
      header=`echo "HTTP/1.1 200 OK
                    Connection: close
                    Content-Length: $filesize
                    " | strip_margin | convert_newlines`
      echo "$header" >&$output
      cat "$filename" >&$output
      echo "file \"$filename\" sent"
    else
      echo "not found"
      header=`echo "HTTP/1.1 404 Not Found
                    Connection: close
                    Content-Length: 0
                    " | strip_margin | convert_newlines`
      echo "$header" >&$output
    fi
    filename=""
    echo
  fi
done <&$input
