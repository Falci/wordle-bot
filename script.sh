#!/bin/bash

# Authenticate
## Youtube
YT_TOKEN=`curl https://www.googleapis.com/oauth2/v4/token \
    -d client_id=$YT_CLIENT_ID \
    -d client_secret=$YT_CLIENT_SECRET \
    -d refresh_token=$YT_REFRESH_TOKEN \
    -d grant_type=refresh_token -s | jq -r '.access_token'`


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