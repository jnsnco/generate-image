#!/bin/bash

SPATH="./.secret.sh"

OAI_URL="https://api.openai.com/v1/images/generations"
MODEL="dall-e-3"
SIZE="1024x1024"

if [ -r $SPATH ]; then . $SPATH
else echo "ERROR: API key file not found."; exit 99
fi
if [ "Z$API_KEY" = "Z" ]; then echo "ERROR: API key not found in file."; exit 98
fi

DEBUG=0 # DEBUG outputs 
if [ "Z$DEBUG" = "Z1" ]; then
	echo -en "\nAPI KEY: $API_KEY\n"
	echo -en "OpenAI URL: $OAI_URL\n"
	echo -en "MODEL: $MODEL\n\n"
fi

echo -en "\nThis program accepts prompts and returns images from OpenAI, along with a record of the exchange in a json file. Files are timestamped based on the initial prompt submission.\n"

while :
do
echo -en "\nCTRL-C to exit. Enter a prompt: "
read PROMPT

echo -en "\nReview prompt before submission:\n\n\t$PROMPT\n\nGenerate image? [Y/n]? "
read confirm
if [ "Z$confirm" != "Z" ] && [ "Z$confirm" = "n" ]; then exit 2; fi

TS=`date +%s`; LOUT=$TS.log; TOUT=$TS.tmp; FOUT=$TS.json

echo -en "\nGenerating image... "
curl $OAI_URL \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "'"$MODEL"'",
    "prompt": "'"$PROMPT"'",
    "n": 1,
    "size": "1024x1024"
  }' \
  --output $TOUT 2>> $LOUT
if [ "Z$?" != "Z0" ]; then
	echo "ERROR: image generation failed, curl returned error code $?. Refer to log file for details."; exit 97
else
	echo "Done."
fi

# bit kludgy - sed removes the leading double quote and %? removes the trailing
# one. curl will barf if you pass it a IMG_URL in double quotes via bash var.
IMG_URL=`cat $TOUT | grep https | sed s/.*url\"\:\ \"//`; IMG_URL=${IMG_URL%?}

FNAME=`echo $PROMPT | cut -c -32 | sed 's/[^a-zA-Z0-9]/_/g'`
echo -en "Downloading image... "
curl $IMG_URL --output ${TS}_${FNAME}.png 2>> $LOUT
if [ "Z$?" != "Z0" ]; then
	echo "ERROR: image retrieval failed, curl returned error code $?. Refer to log file for details."; exit 96
else
	echo "Done."
fi
file_info=`ls -D '%s' -l ${TS}_${FNAME}.png`
FSIZE=`echo $file_info | cut -d " " -f 5`
FTS=`echo $file_info | cut -d " " -f 6`
FNAME=`echo $file_info | cut -d " " -f 7`

if [ "Z$DEBUG" = "Z1" ]; then
	echo -en "\n\nfilename: $FNAME\n\nprompt: $PROMPT\n\n"
	echo -en "\n\n$file_info\n$FSIZE\n$FTS\n$FNAME\n\n"
fi

# NOTES
# . print out the json manually to avoid needing jq or similar (zero dep goal) 
# . n=1 is hardcoded, OpenAI doesn't support other 'n's for image generation anyway
echo -en "{\n\
  \"created\": $TS,\n\
  \"data\": [\n\
    {\n\
      \"generate_url:\": \"$OAI_URL\",\n\
      \"model\": \"$MODEL\",\n\
      \"original_prompt\": \"$PROMPT\",\n\
      \"n\": 1,\n\
      \"size\": \"$SIZE\",\n" > $FOUT

cat $TOUT | grep "\"revised_prompt\": " >> $FOUT
cat $TOUT | grep "\"url\": " | sed -e s/\"url\":\ /\"image_url\":\ / -e s/$/,/ >> $FOUT

echo -en "      \"filename\": \"$FNAME\",\n\
      \"filesize\": \"$FSIZE\"\n\
    }\n\
  ]\n\
}\n" >> $FOUT

echo -en "\n\n  --== JSON Output ==--\n\n"
cat $FOUT
rm $TOUT $LOUT

done
