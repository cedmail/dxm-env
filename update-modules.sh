#!/usr/bin/env zsh

# Build and deploy DX and GraphQL for SDL Development and Testing

# What needs to be done:
#  1. Get dxm-dev-private repo from github
#  2. Do checkout-jahia.sh in dxm-dev-private then in ./jahia-ee-root and ./jahia-root switch to feature-BACKLOG-8990 branch
#  3. Build/Deploy DX to a profile
#  4. Navigate to the /DX-TOMCAT-PATH/digital-fatory-data/modules/
#  5. Remove default graphql*.jar files
#  6. Copy site-map-2.0.6-SNAPSHOT.jar into /DX-TOMCAT-PATH/digital-fatory-data/modules/
#  7. Get graphql-core repo from github then switch to custom-api branch
#  8. Deploy graphql-core branch using profile
#  9. Remove old external provider and deploy new one
# 10. Start DX

usage(){
    echo "usage: create-env.sh [[[-p|--profile profile ] [-f|--folder folder] [-b|--branch branch] [-m|--modules modules]] | [-h]]"
}

profile=default;
folder=DX;
modulesfilename="modules.config";

if [[ $#@ == 0 ]]; then
	usage;
	exit 1;
fi

while [[ "$1" != "" ]]; do
    case $1 in
        -p | --profile )        shift
                                profile=$1
                                ;;
        -f | --folder )    		shift
								folder=$1
                                ;;
        -m | --modules )    	shift
								modulesfilename=$1
								;;															
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

#find and store path to main directory
mainDir=`pwd`;
envDir=`echo $mainDir/$folder`;

if [ ! -d $envDir ]; then
	mkdir $envDir
fi

echo "Found path to main directory $mainDir with profile $profile and folder $folder with modules list $modulesfilename";

IFS=';'

cat $mainDir/$modulesfilename | while read -A repo; do
	echo "found github repos to clone $repo[1] $repo[2] $repo[3]"	
	cd $envDir
	if [ ! -d $envDir/$repo[2] ]; then
		git clone $repo[1] $repo[2];
		cd $envDir/$repo[2]; 
		if [[ $#repo == 3 ]]; then
			git checkout $repo[3];
		fi
		sed -i '' 's/7\.[0-9]\.[0-9]\.[0-9]/7\.3\.0\.0/g' pom.xml
		#deploy repo to profile
		mvn -P $profile -D skipTests clean install jahia:deploy;
	else 
		cd $envDir/$repo[2]; 
		#update repo
		updated=$(git fetch;git pull)
		if [[ $updated != "Already up to date." ]]; then
			sed -i '' 's/7\.[0-9]\.[0-9]\.[0-9]/7\.3\.0\.0/g' pom.xml
			#deploy repo to profile
			mvn -P $profile -D skipTests clean install jahia:deploy;
		else 
			echo $updated	
		fi	
	fi		
done
