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
								modules=$1
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

echo "Found path to main directory $mainDir with profile $profile and folder $folder";

tcPort=0;
#---find port to tomcat with specified profile
grep -o -A 10 -e "<id>$profile</id>" ~/.m2/settings.xml | while read -r line; do
    if [[ $line =~ '<jahia\.test\.url>[^<].*/' ]]; then
                tcPort=${MATCH[34, 37]};
                break;
    fi
done

echo "Tomcat port from profile $profile is $tcPort";
if [[ $tcPort == 0 ]]; then
	exit 1;
fi

#---kill all processes on this port
kill -9 $(lsof -t -i:$tcPort);

#find path to target tomcat with specified profile
grep -o -A 10 -e "<id>$profile</id>" ~/.m2/settings.xml | while read -r line; do
    if [[ $line =~ '<jahia\.deploy\.targetServerDirectory>/[^<].*/' ]]; then
                (( patternEnd = $MEND - 2))
                tcPath=${MATCH[37, $patternEnd]};
                break;
    fi
done
echo "Found tomcat path inside maven settings " $tcPath;

#clean tomcat directory
rm -Rf $tcPath/digital-factory-*; 
rm -Rf $tcPath/webapps/*; 
rm -Rf $tcPath/logs/*; 
rm -Rf $tcPath/work/*;

if [ -d $envDir/dxm ]; then
	cd $envDir/dxm;	
	."/update-jahia.sh"; 

	."/clean-ee.sh";."/install-ee.sh";
fi

#build and deploy to profile
cd $envDir/$folder;
./deploy-ee-with-tests.sh $profile;
mvn -P $profile jahia:configure;

IFS=';'

cat $mainDir/$modulesfilename | while read -A repo; do
	echo "found github repos to clone $repo[1] $repo[2] $repo[3]"	

	if [ ! -d $envDir/$repo[2] ]; then
		git clone $repo[1] $repo[2];
		cd $envDir/$repo[2]; 	
		if [[ $#repo == 3 ]]; then
			git checkout $repo[3];
		fi
	fi
	
	cd $envDir/$repo[2]; 
	
	#update repo
	updated=$(git fetch;git pull)
	if [[ $updated != "Already up to date." ]]; then
		sed -i '' 's/7\.0\.0\.0/7\.3\.0\.0/g' pom.xml
		#deploy repo to profile
		mvn -P $profile -D skipTests clean install jahia:deploy;
	else 
		echo $updated	
	fi
done

#start-up dx server
$tcPath/bin/catalina.sh run;
