function main () {
  SRC_ANIME_ID=$1
  F_RATE=$2
  S3_BUCKET=$3
  echo "$SRC_ANIME_ID, $F_RATE, $S3_BUCKET"

  SRC_MOD=$(($SRC_ANIME_ID % 1000))
  S3_BASE_PATH=s3://$S3_BUCKET/animes/$SRC_MOD/anime_$SRC_ANIME_ID
  MP4_FILENAME=${SRC_ANIME_ID}.mp4
  S3_DST_MP4_PATH=$S3_BASE_PATH/$MP4_FILENAME

  # exist check
  #echo $S3_DST_MP4_PATH
  EXIST_MP4=`aws s3 ls $S3_DST_MP4_PATH | wc -l | tr -d ' ' || :`
  if [ $EXIST_MP4 -eq 1 ]; then
    #echo "already exist at $S3_DST_MP4_PATH"
    echo exist
    exit 0
  fi

  #echo "start encoding mp4...: $S3_DST_MP4_PATH"

  # mkdir
  TMP_DIR=/tmp/anime/$SRC_ANIME_ID
  WHITE_DIR=/tmp/anime/white
  mkdir -p $TMP_DIR
  mkdir -p $WHITE_DIR
  cd $TMP_DIR

  # sync images
  #echo $S3_BASE_PATH
  aws s3 sync $S3_BASE_PATH . || :

  # size
  HEAD_IMG_FILE=`ls -1 $TMP_DIR | sort | head -n 1`
  HEAD_IMG_PATH=$TMP_DIR/$HEAD_IMG_FILE
  SIZE=`identify -format '%wx%h' $HEAD_IMG_PATH`
  #echo $HEAD_IMG_PATH
  #echo $SIZE

  # create white
  WHITE_PATH=$WHITE_DIR/white.gif
  `convert -size $SIZE xc:white $WHITE_PATH`
  #ls $WHITE_PATH

  # composite white
  RES=`find . -type f -name '*.png' | xargs -I {} composite {} $WHITE_PATH {}`
  #echo $RES

  # mp4
  SRC_PATH=$TMP_DIR/${SRC_ANIME_ID}_%d.png
  DST_PATH=$TMP_DIR/$MP4_FILENAME
  ffmpeg -y -r $F_RATE -i $SRC_PATH -pix_fmt yuv420p -vf 'scale=trunc(iw/2)*2:trunc(ih/2)*2' $DST_PATH
  #echo $DST_PATH

  # upload mp4 to s3
  aws s3 cp $DST_PATH $S3_DST_MP4_PATH || :
  echo finish
}

function handler () {
  echo $JQ_CMD
  INPUT=`echo $1 | sed -e 's/\\\\//g'`
  echo $INPUT
  SRC_ANIME_ID=`echo $INPUT | $JQ_CMD .anime_id`
  F_RATE=`echo $INPUT | $JQ_CMD .frame_rate`
  S3_BUCKET=`echo $INPUT | $JQ_CMD .bucket | sed -e 's/"//g'`
  main $SRC_ANIME_ID $F_RATE $S3_BUCKET
}
