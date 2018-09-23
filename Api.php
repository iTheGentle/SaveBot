<?php
ini_set('display_errors', 1);
require_once('TwitterAPIExchange.php');
$Data = $_POST['Data'];
if(!empty($Data)){
$Data = base64_decode($Data);

$Data = explode("|",$Data);
/** Set access tokens here - see: https://dev.twitter.com/apps/ **/
$settings = array(
    'oauth_access_token' => $Data[2],
    'oauth_access_token_secret' => $Data[3],
    'consumer_key' => $Data[0],
    'consumer_secret' => $Data[1]
);

$url = 'https://api.twitter.com/1.1/statuses/show.json';
$getfield = '?include_profile_interstitial_type=1&include_blocking=1&include_blocked_by=1&include_followed_by=1&include_want_retweets=1&skip_status=1&cards_platform=Web-12&include_cards=1&include_ext_alt_text=true&include_reply_count=1&tweet_mode=extended&trim_user=false&include_ext_media_color=true&id='.$Data[4];
$requestMethod = 'GET';
$twitter = new TwitterAPIExchange($settings);

$req = json_decode($twitter->setGetfield($getfield)
             ->buildOauth($url, $requestMethod)
             ->performRequest());
$req  = $req->extended_entities->media[0]->video_info->variants;

for($i=0 ; $i < count($req) ; $i++)
{

  if(strpos($req[$i]->url,".m3u8") != true){
    $title=explode("/vid/",$req[$i]->url);
    $title=explode("/",$title[1]);
    echo $title[0]."^".$req[$i]->url."#";

  }
echo "SaveBot Under maintance 🌹^";

}}
else {
  //echo "Nothing To Do !";
  echo "SaveBot Under maintance 🌹^#";
}

?>
