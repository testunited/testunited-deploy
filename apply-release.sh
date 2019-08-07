#! /bin/bash
#registry_host="asia.gcr.io"
registry_ns="testunited"
registry_user="chamithsri"
app_name="testunited"
app_display_name="TestUnited"
chart_file="$app_name/Chart.yaml"
image_values_file="$app_name/values.images.yaml"
manifest_file="manifest.yaml"
app_version=$1
environment=$2
registry_key_file=$3
app_version_match_string="appVersion: \"$app_version\""
app_version_matched=$(grep -c "$app_version_match_string" "$chart_file")

if [ $app_version_matched != 1 ]
then
  echo "App version in Helm Chart does not match with the version mentioned."
  exit 0
fi

if [ ! -n "$environment" ]
then
  echo "Target environment is not provided."
  exit 0
else
  env_values_file="$app_name/values.$environment.yaml"
  release_name="$app_name-$environment"
  kube_ns="$app_name-$environment"
fi

if [ -n "$registry_key_file" ]
then
  cat $registry_key_file | docker login -u $registry_user --password-stdin
fi

echo "#### TestUnited v$app_version #####" > $image_values_file
echo "# Service Images" >> $image_values_file
echo "images:" >> $image_values_file

while read name sem_ver build_seq rc_seq ; do
  
  build_tag="$sem_ver-$build_seq"

  if [ $environment == "prd" ]
  then
    release_tag="$sem_ver"
  else
    release_tag="$sem_ver-$rc_seq"
  fi

  printf "%s\n" "name: ${name}"
  printf "%s\n" "build_tag: ${build_tag}"
  printf "%s\n" "release_tag: ${release_tag}"
  image_full_name="$registry_ns/$app_name-$name"
  docker pull "$image_full_name:${build_tag}"
  docker tag "$image_full_name:${build_tag}" "$image_full_name:${release_tag}"
  docker push "$image_full_name:${release_tag}"
  echo "  $name: $image_full_name:${release_tag}" >> $image_values_file
done < $manifest_file

helm upgrade -i -f $image_values_file -f $env_values_file --namespace $kube_ns --description appVersion:$app_version $release_name $app_name

git_tag="v$app_version"
echo "tagging git with $git_tag"
git tag $git_tag
git push origin HEAD:master $git_tag
echo "DONE: tagging git with $git_tag"
