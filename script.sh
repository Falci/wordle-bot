#!/bin/bash

# Authenticate
NOW=$( date +%s )
IAT="${NOW}"
EXP=$((${NOW} + 600))

HEADER_RAW='{"alg": "RS256","typ": "JWT"}'
HEADER=$( echo -n "${HEADER_RAW}" | openssl base64 | tr -d '\n' | tr -d '=' | tr '/+' '_-' )

CLAIM_RAW='{
    "iat": '"${IAT}"',
    "exp": '"${EXP}"',
    "iss": "'"${ISS}"'",
    "scope": "https://www.googleapis.com/auth/youtube.upload",
    "aud": "https://oauth2.googleapis.com/token"
}'
CLAIM=$( echo -n "${CLAIM_RAW}" | openssl base64 | tr -d '\n' | tr -d '=' | tr '/+' '_-' )

HEADER_CLAIM="${HEADER}"."${CLAIM}"

SIGNATURE=$( openssl dgst -sha256 -sign <(echo -n "${PEM}") <(echo -n "${HEADER_CLAIM}") | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n' )
JWT="${HEADER_CLAIM}"."${SIGNATURE}"

## Youtube
YT_TOKEN=`curl \
    -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
    -d "assertion=$JWT" \
    https://oauth2.googleapis.com/token -s | jq -r '.access_token'`


# Load content
DESC=`cat ./description.txt`
SHARE=`cat ./share.txt`

TITLE=$(echo "$SHARE" | head -n 1)
DAY=$(echo $TITLE | awk '{print $2}')
SCORE=$(echo $TITLE | awk '{print $3}')
DESC="$SHARE $DESC"

# Youtube
## 1. Create a video resource
LOCATION=`curl "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status&key=$YT_CLIENT_ID" \
    --header "Authorization: Bearer $YT_TOKEN" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --data '{"snippet": {"title": "'"$TITLE"'","description": "'"$DESC"'","tags": ["wordle", "day'"$DAY"'", "shorts"]},"status": {"privacyStatus": "public"}}' \
    --dump-header /dev/fd/1 \
    --silent | grep location | awk '{print $2}'`

## 2. Check if there's quota
if [ -z "$LOCATION" ]; then
    echo "Error: Could not upload the video to YouTube."
    exit 0;
fi

echo "Created video: $LOCATION"

## 3. Add a background audio
### Choose a music
AUDIOS=(./audio/*.mp3)
AUDIO_INDEX=$(($DAY % ${#AUDIOS[@]}))
AUDIO=${AUDIOS[$AUDIO_INDEX]}

### Video + music
ffmpeg -loglevel error -i video.mp4 -i "$AUDIO" -map 0:v -map 1:a -c:v copy -shortest output.mp4 

## 4. Upload the video
curl "$LOCATION" \
    --header "Authorization: Bearer $YT_TOKEN" \
    --header 'Content-Type: application/octet-stream' \
    --data-binary @output.mp4