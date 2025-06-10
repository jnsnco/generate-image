#!/bin/bash

SPATH="./.secret.sh"
OAI_URL="https://api.openai.com/v1/images/generations"
#MODEL="gpt-4.1-mini"
MODEL="gpt-image-1"
MODEL="dall-e-3"
#SIZE="1024x1792"
SIZE="1024x1024"
IMG_DIR="./img"
JSON_DIR="./json"

# TODO 
# - add optional CLI parameters for all of these ^

if [ -r $SPATH ]; then . $SPATH
else echo "ERROR: Path to API key file not found."; exit 99
fi
if [ "Z$API_KEY" = "Z" ]; then echo "ERROR: API key not found in file."; exit 98
fi

DEBUG=1 # DEBUG outputs 
DEBUG=0 # or don't
if [ "Z$DEBUG" = "Z1" ]; then
	echo -en "\nAPI KEY: $API_KEY\n"
	echo -en "OpenAI URL: $OAI_URL\n"
	echo -en "MODEL: $MODEL\n\n"
fi

echo -en "\nThis program accepts prompts and returns images from OpenAI, along with a record of the exchange in a json file. Files are timestamped based on the initial prompt submission.\n"

COUNT=1; isnum='^[0-9]+$'

while :
do
let COUNT--
# echo "C1 $COUNT" # DEBUG
if [ "Z$COUNT" = "Z0" ]; then
	echo -en "\nCTRL-C to exit. Hit enter to run the previous prompt again, or enter a prompt: "
	read INPUT
	if [ "Z$INPUT" != "Z" ]; then
		PROMPT=$INPUT
	else
		echo -en "Reusing the previous prompt. "
	fi

	echo -en "\nHow many images do you want? "
	read COUNT
	if [ "Z$COUNT" = "Z" ]; then COUNT=1
	elif ! [[ $COUNT =~ $isnum ]]; then COUNT=1
	fi
# echo "C2 $COUNT" # DEBUG

	echo -en "\nReview prompt before submission:\n\n\t$PROMPT\n\nGenerate image? [Y/n]? "
	read confirm
	if [ "Z$confirm" != "Z" ] && [ "Z$confirm" = "n" ]; then exit 2; fi
else
	echo -en "Remaining images to generate: $COUNT. "
fi

TS=`date +%s`; LOUT=$TS.log; TOUT=$TS.tmp; FOUT=$TS.json

echo -en "\nGenerating image... "
curl $OAI_URL \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "'"$MODEL"'",
    "prompt": "'"$PROMPT"'",
    "n": 1,
    "size": "'"$SIZE"'"
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
# again a bit kludgy - after this, $FNAME includes $TS, the timestamp 
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

# Attempt to move files to their respective dirs, leave them where they are if there's any problem
mv $FOUT $JSON_DIR
mv $FNAME $IMG_DIR

done
