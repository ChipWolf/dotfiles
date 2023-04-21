#/bin/bash

STATION="EGOM"

while [ ! $# -eq 0 ]; do
  case $1 in 
    --help | -h)
      shift
      exit 0
      ;;
    --api-key | -a)
      shift
      CWX_API_KEY=$1
      shift
      ;;
    --station | -s)
      shift
      STATION=$1
      shift
      ;;
    *)
      break
      ;;
  esac
done

if [ -z $CWX_API_KEY ]; then
  echo "API Key is not set. Set it with --api-key or -a or the environment variable CWX_API_KEY"
  exit 1
fi

DATA=$(curl -s "https://api.checkwx.com/metar/$STATION" -H "X-API-Key: $CWX_API_KEY" | /usr/local/bin/jq --raw-output .data[0])

echo $DATA
