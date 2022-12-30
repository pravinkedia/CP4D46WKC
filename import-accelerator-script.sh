#!/bin/bash

#################################################################################################################################################
# Copyright IBM Corp. 2020,2021
# All Rights Reserved
#################################################################################################################################################

# Log handling function

clear


log_msg()
{
        declare l_sev=$1
        declare l_msg=$2
        declare l_logfile=$3
        TIMESTAMP=`date "+%Y-%m-%d-%H:%M:%S"`

        RED='\033[0;31m'
        NC='\033[0m' # No Color
        GREEN='\033[32m'
	YELLOW='\033[33m'

        case $l_sev in
                "ERROR") l_colour=$RED ;;
		"WARNING") l_colour=$YELLOW ;;
                "SUCCESS") l_colour=$GREEN ;;
                *) l_colour=$NC ;;
        esac

        echo -e "${l_colour}[$TIMESTAMP][$l_sev] : $l_msg ${NC}" >> $l_logfile
        echo -e "${l_colour}[$l_sev] : $l_msg ${NC}"
}

#################################################################################################################################################
# Process command line arguments and flag parameters
#################################################################################################################################################

for arg in "$@"
do
	case $arg in
                -h|--hostname)
                        CPD_HOST="$2"
                        shift
			shift
                        ;;
                -u|--username)
                        username="$2"
                        shift
			shift
                        ;;
                -p|--password)
                        password="$2"
                        shift
			shift
                        ;;
                -n|--name)
                        analytics_project="$2"
                        shift	
			shift
                        ;;
		-f|--file)
                        tarfile="$2"
                        shift
                        shift
                        ;;
		-g|--publish_glossary)
			publish_glossary_terms="Y"
			shift
			;;
		-j|--run_jobs)
			run_notebook_jobs="Y"
			shift
			;;
		-v|--version)
			echo
			echo "[INFO] : Industry Accelerator Import Script - Version 2.0"
			shift
			exit 0
			;;
		--help) 
			echo
			echo "Cloud Pak for Data - Industry Accelerator Import"
			echo 
			echo
			echo "Usage: ./import-acclerator-script.sh [flags]"
			echo
			echo 
			echo "Flags :"
			echo
			echo "       -f, --file              :   The name of the accelerator tar.gz file. Use this flag only if you are importing an unextracted tar.gz file"
			echo "       -h, --hostname          :   The host URL of the Cloud Pak for Data cluster e.g. https://<hostname:port>"
			echo "       -u, --username          :   The username for the Cloud Pak for Data cluster"
			echo "       -p, --password          :   The password for the Cloud Pak for Data cluster"
			echo "       -n, --name              :   The name you wish to use for the analytics project"
			echo "       -v, --version           :   Display version information for this script"
			echo "       -g, --publish_glossary  :   Publish the Watson Knowledge Catalog business terms during the import process (optional). If not set the business terms will be created in draft state."
			echo "       -j, --run_jobs          :   Execute the notebook jobs specified in the analytics project during the import process (optional)"
			echo "           --help              :   Help for accelerator import process"
			echo
			echo "These arguments are optional and can be declared in any order."
			echo "You can also execute the script without arguments, in which case you will be prompted for the required information."
			echo
			echo "Example syntax without arguments..."
			echo
			echo "Example syntax Bash Users : ./import-accelerator-script.sh "
			echo "Example syntax Windows Users : bash -c ./import-accelerator-script.sh "
			echo
			echo "Example syntax if you have extracted the .tar.gz file and are executing the import script that was included..."
			echo "Note that in this scenario the script and the artefacts are in the same path"
			echo "Example syntax Bash Users : ./import-accelerator-script.sh --hostname https://hostname:port --username username --password password --name name-of-project"
                        echo "Example syntax Windows Users : bash -c ./import-accelerator-script.sh --hostname https://hostname:port --username username --password password --name name-of-project"
			echo
			echo "Example syntax if you are importing an unextracted .tar.gz file (this method can be useful if you have multiple .tar.gz files to process..."
			echo "Example syntax Bash Users : ./import-accelerator-script.sh --file accelerator-file-name.tar.gz --hostname https://hostname:port --username username --password password --name name-of-project"
			echo "Example syntax Windows Users : bash -c ./import-accelerator-script.sh --file accelerator-file-name.tar.gz --hostname https://hostname:port --username username --password password --name name-of-project"
			shift
			exit 0
			;;
		$1)
			echo "[ERROR] : Invalid parameter(s). User --help argument to get assistance on usage of the parameter(s)."
			exit 0
			shift
			;;
	esac
done

echo

#################################################################################################################################################

# Set accelerator name & create logfile

TIMESTAMP=`date "+%Y-%m-%d-%H:%M:%S"`
logtime=$TIMESTAMP

if [[ -z "$tarfile" && $PWD == *-industry-accelerator ]]
then	
	
	accelerator=${PWD%-industry-accelerator}
	accelerator_name=`echo "$accelerator" | rev | cut -d"/" -f1  | rev`

elif [[ ! -z "$tarfile" && $tarfile == *-industry-accelerator.tar.gz && $PWD != *-industry-accelerator ]]
then
	accelerator=${tarfile%-industry-accelerator.tar.gz}
        accelerator_name=`echo "$accelerator" | rev | cut -d"/" -f1  | rev`
fi


if [[ $accelerator_name == "" ]]
then 
	logfile=accelerator-$logtime.log
else 
	logfile=$accelerator_name-$logtime.log
fi


log_msg "INFO" "$accelerator_name industry accelerator import process" "$logfile"
log_msg "INFO" "Starting script...." "$logfile"

# Notebook run warning

if [[ $run_notebook_jobs == 'Y' ]]
then
        log_msg "WARNING" "Note that the notebook job run duration may vary from 8 to 15 minutes depending on the accelerator and CPD cluster..." "$logfile"
fi

#################################################################################################################################################
# Config section & argument checks
#################################################################################################################################################
# Check host is reachable

while [[ -z "$CPD_HOST" ]]
do 
	echo
   	# Read Variables from User
	echo "[INFO] : Script parameter Cloud Pak for Data Hostname required." 
	echo "[INFO] : Run ./import-accelerator.sh --help for further help."
   	echo "Enter host URL for your Cloud Pak for Data Cluster in this format : https://<hostname:port> "
	echo
 	read -t300 -p 'Enter Host URL : ' CPD_HOST
	if [[ $? -gt 300 || -z "$CPD_HOST" ]]
        then
                echo
                log_msg "ERROR" "No input entered by user for host URL. Aborting import..." "$logfile"
                exit 0
        fi

done

if [[ $CPD_HOST != https://* ]]
then
	CPD_HOST=https://$CPD_HOST
fi

if [[ $CPD_HOST == */ ]] 
then
 	CPD_HOST=${CPD_HOST%?}
fi

# Cluster Sanity Check 

if curl -k --output /dev/null --silent --head --fail "$CPD_HOST"; then
	echo
	log_msg "INFO" "Cloud Pak for Data cluster exists and is reachable... " "$logfile" 
else
	echo
	log_msg "ERROR" "Cannot reach Cloud Pak for Data cluster..." "$logfile"
	exit 0
fi

# Endpoint & headers for authentication

declare -a authURL="${CPD_HOST}/icp4d-api/v1/authorize"

declare -a curlArgs1=('-H' "Content-Type: application/json" \
        '-H' "cache-control: no-cache")


#################################################################################################################################################
# Gather host and credentials
#################################################################################################################################################

while [[ -z "$username" ]]
do 
	echo
	echo "[INFO] : Script parameter Username required. "
	echo "[INFO] : Run ./import-accelerator.sh --help for further help."
	read -t300 -p 'Enter USERNAME : ' username
	if [[ $? -gt 300 || -z "$username" ]]
        then
                echo
                log_msg "ERROR" "No input entered by user for username. Aborting import..." "$logfile"
                exit 0
        fi
done

while [[ -z "$password" ]]
do
	echo
	echo "[INFO] : Script parameter Password required. "
	echo "[INFO] : Run ./import-accelerator.sh --help for further help."
        read -t300 -sp 'Enter PASSWORD : ' password
	if [[ $? -gt 300 || -z "$password" ]]
        then
                echo
                log_msg "ERROR" "No input entered by user for password. Aborting import..." "$logfile"
                exit 0
        fi

done

#################################################################################################################################################
# Check authentication is successful
#################################################################################################################################################

credentials='{"username":"'$username'","password":"'$password'"}'

HTTP_CODE=$(curl -s --write-out "%{http_code}\n" -k -X POST "${curlArgs1[@]}" \
                -d "$credentials" \
                 ${authURL} \
		--output output.txt) 


if [[ $HTTP_CODE == 200 ]]
then
	echo
	log_msg "SUCCESS" "Authentication completed and successful..." "$logfile"

else
	echo
	log_msg "ERROR" "Authentication check returned error... $HTTP_CODE" "$logfile"
       	log_msg "ERROR" "Please check your username/password. Please also check your Cloud Pak for Data Host URL." "$logfile"
	rm -rf output.txt
	exit 0 
fi

#################################################################################################################################################
# Check if user has required permissions to import the accelerator
#################################################################################################################################################

echo
json=$(curl -s -k "$authURL" \
            -X POST "${curlArgs1[@]}" \
            -d "$credentials") \
   		&& token=$(echo $json | sed "s/{.*\"token\":\"\([^\"]*\).*}/\1/g") \
	

log_msg "INFO" "Checking for user permissions...." "$logfile"

user_permissions=$(curl -s -k -X GET -H "Authorization: Bearer $token" \
        	-H "cache-control: no-cache" "${CPD_HOST}/icp4d-api/v1/users/$username")

if echo $user_permissions | grep -q  -e "Administrator" -e "Data Steward" -e "Data Engineer" -e "Data Quality Analyst" -e "zen_administrator_role" -e "wkc_data_steward_role" -e "wkc_data_scientist_role" -e "zen_data_engineer_role" 
then
	echo
   	log_msg "INFO" "User has necessary privileges for both project and glossary import." "$logfile"

else
	log_msg "WARNING" "Administrator, Data Steward, Data Engineer or Data Quality Analyst user permissions needed." "$logfile"
   	read -t300 -p 'User does not have permissions for managing Watson Knowledge catalog, Do you wish to continue with import? (Enter y/n) : ' ch
	if [ $? -gt 300 ]
       	then
               	echo
               	log_msg "ERROR" "No input entered by user. Aborting import..." "$logfile"
		rm -rf output.txt
               	exit 0
       	fi


   	if [[ $ch == 'y' || $ch == 'Y' ]]
   	then
    		import_without_glossary=1

   	elif [[ $ch == 'n' || $ch == 'N' ]]
	then 
		log_msg "INFO" "Stopping import process..." "$logfile"
		rm -rf output.txt
		exit 0
	else
		log_msg "ERROR" "Invalid Input - stopping import process" "$logfile"
		rm -rf output.txt
    		exit 0 
   	fi
fi

#################################################################################################################################################
# Check which method is being used -- import unextracted tar.gz file or import extracted content.
#################################################################################################################################################

if [[ $PWD == *-industry-accelerator && ! -z "$tarfile" ]]
then
	echo
	log_msg "ERROR" "Please specify only one of these two flags...." "$logfile"
	log_msg "INFO" "Option 1 : Without flag. The script must be executed from the extracted accelerator folder."
	log_msg	"INFO" "Option 2 : Via .tar.gz file. The downloaded accelerator tar.gz. Ensure tha the script and tar.gz file have the same path. [Use flag -f/--file] "
	echo "[INFO] : Run ./import-accelerator.sh --help for further help."
	rm -rf output.txt
	exit 0
fi


#################################################################################################################################################

if [[ $PWD != *-industry-accelerator && -z "$tarfile" ]]
then
	echo 
	echo "[INFO] : Script Parameter tar.gz file missing."
	echo "[INFO] : Run ./import-accelerator.sh --help for further help."
        echo "Example syntax : accelerator-file-name.tar.gz."
        read -t300 -p 'Please provide the .tar.gz filename : ' tarfile
        if [ $? -gt 300 ]
        then
 	       echo
               log_msg "ERROR" "No input entered by user for the file. Aborting import..." "$logfile"
               rm -rf output.txt
               exit 0
        fi
fi


#################################################################################################################################################

if [[ ! -z "$tarfile" && $PWD != *-industry-accelerator ]]
then
	script_exe_with_tar=1
	current_path=$PWD
	
elif [[ $PWD == *-industry-accelerator ]]
then 
	script_exe_with_tar=0
	current_path=$PWD

else 
	script_exe_with_tar=1
	current_path=$PWD
fi

#################################################################################################################################################
# Check if wkc glossary files exist
#################################################################################################################################################

if [[ $script_exe_with_tar == 0 ]]
then
	if [[ ! -f "$accelerator_name-glossary-categories.csv" && ! -f "$accelerator_name-glossary-terms.csv" ]]
	then
		echo
                log_msg "ERROR" "Business glossary terms and categories files not found..." "$logfile"
		rm -rf output.txt
                exit 0 
	fi
	
	project_zipfile="$accelerator_name-analytics-project.zip"
fi

#################################################################################################################################################
# Check if tar.gz file exist
#################################################################################################################################################

if [[ $script_exe_with_tar == 1 ]]
then
	current_path=$PWD

	while [[ -z "$tarfile" ]]
	do
		echo
        	echo "[INFO] : Script parameter Tar.gz file required. "
		echo "[INFO] : Run ./import-accelerator.sh --help for further help."
		echo "Example syntax : accelerator-file-name.tar.gz."
		read -t300 -p 'Please provide the .tar.gz filename : ' tarfile
		if [ $? -gt 300 ]
		then
			echo
			log_msg "ERROR" "No input entered by user for tar.gz filename. Aborting import..." "$logfile"
			rm -rf output.txt
			exit 0	
		fi	
	done
	
	if [[ ! -f "$tarfile" ]]
	then 
		log_msg "ERROR" "Tar.gz file not found... Aborting project." "$logfile"
		rm -rf output.txt
                exit 0

	fi

	# Tar file check and extraction of content. 
	echo

	if ! tar -zxvf "$tarfile"
	then
        	log_msg "ERROR" "Invalid tar.gz file... Please check." "$logtime"
		rm -rf output.txt
        	exit 0
	else
		echo
		log_msg "INFO" "Extracted accelerator artefacts successfully... " "$logfile"
	fi


	accelerator=${tarfile%-industry-accelerator.tar.gz}

	accelerator_name=`echo "$accelerator" | rev | cut -d"/" -f1  | rev`
	
	if [[ -f "$current_path/$accelerator_name-industry-accelerator/$accelerator_name-glossary-categories.csv" && -f "$current_path/$accelerator_name-industry-accelerator/$accelerator_name-glossary-terms.csv" ]]
	then
        	log_msg "INFO" "Business Glossary categories and terms files found" "$logfile"
	else
		echo
        	log_msg "ERROR" "Business glossary terms and categories files not found... Please check the content/tar.gz file." "$logfile"
        	rm -rf output.txt
        	exit 0
	fi
	project_zipfile="$current_path/$accelerator_name-industry-accelerator/$accelerator_name-analytics-project.zip"
fi


log_msg "INFO" "Industry Accelerator being imported : $accelerator_name" "$logfile"


if [[ -z "$project_zipfile" ]]
then 
	echo
	log_msg "INFO" "Please ensure that the script and tar.gz file/accelerator artefacts are in the same directory and try again." "$logfile"
	rm -rf output.txt
	exit 0
fi
	

if [[ ! -f $project_zipfile ]]
then
       	skip_Project_Import=1
        echo
	log_msg "INFO" "This accelerator contains business terms and categories for Watson Knowledge Catalog and no analytics project." "$logfile"
else
       	skip_Project_Import=0
	echo
	log_msg "INFO" "This accelerator contains an analytics project, business terms and categories files." "$logfile"

	if [[  `stat -c %s $project_zipfile` == 0 ]]
	then
		log_msg "WARNING" "The analytics project is empty, project import will skipped..." "$logfile"
		skip_Project_Import=1
	fi

fi


#################################################################################################################################################
# Provide name for project and start import of project
#################################################################################################################################################

if [[ $skip_Project_Import == 0 ]]
then
	echo
	log_msg "INFO" "Starting accelerator import process..." "$logfile"

	
	if [[ -z "$analytics_project" ]]
 	then
  		echo "[INFO] : Optional script parameter project name required."
		echo "[INFO] : Run ./import-accelerator.sh --help for further help."
  		read -t 30 -p 'Enter a name for the analytics project. If no name is entered, the script will auto-generate a name : ' project
		
		if [[ ! -z "$project" ]]
 		then
   			analytics_project=$project
  		else
   			analytics_project=$accelerator_name
  		fi
 	fi
	
	
	if [[ ${#analytics_project} -gt 95 ]]
	then 
		log_msg "WARNING" "Project name too large." "$logfile"
		analytics_project=`echo ${analytics_project:0:95}`
		log_msg "INFO" "Project name has been trimmed down to $analytics_project" "$logfile"
	fi 
 	

	# analytics project metadata
 	METADATA='metadata={
  		"name": "'${analytics_project}'",
  		"description": "Industry Accelerator.",
  		"generator": "IndAcc-Projects",
  		"public": false,
  		"tags": [
    			"string"
  			],
  		"storage": {
    			"type": "assetfiles",
    			"guid": "d0e410a0-b358-42fc-b402-dba83316413b"
   			}
 		}'


 	if [[ -z "${METADATA}" ]]; then
    		log_msg "ERROR" "Metadata generation failed." "$logfile"
    		rm -rf output.txt
    		exit 0 
 	else 
		log_msg "INFO" "Metadata created for project." "$logfile"
 	fi

 	declare -a metadata="${METADATA}"
	
 	# endpoint and headers for analytics project import
 	if [ $HTTP_CODE == 200 ]
 	then
  		declare -a curlArgs2=('-H' "Authorization: Bearer $token" \
 			'-H' "content-type:multipart/form-data")

  		log_msg "INFO" "Importing the analytics project..." "$logfile"
		

  		http_proj=$(curl -s --write-out "%{http_code}\n" -X POST -k \
    			"${CPD_HOST}/transactional/v2/projects" \
    			"${curlArgs2[@]}" \
    			-F file=@$project_zipfile \
    			-F "$metadata" \
    				--output output.txt )

    		echo "$TIMESTAMP">>$logfile
		cat output.txt>>$logfile
	
  		if [[ $http_proj == 202 ]]
  		then
			log_msg "INFO" "Importing Project Artefacts..." "$logfile"
			guid=$(cat output.txt | grep -Po '"location":"\K[^"]*' | awk -F / '{print $4}')	
			trans_id=$(cat output.txt | sed "s/{.*\"id\":\"\([^\"]*\).*}/\1/g")	
        
 	 	elif [[ $http_proj == 400 ]]
  		then 
			echo
   			log_msg "WARNING" "Project with this name already exists.... $http_proj" "$logfile"
			log_msg "WARNING" "Attempting to import with unique name..." "$logfile"

   			while [[ $http_proj == 400 ]]
   			do 	
				current_version=$analytics_project
				n=${current_version##*[!0-9]}; p=${current_version%%$n}
				analytics_project=$p$((n+1))
				METADATA='metadata={
  					"name": "'${analytics_project}'",
			  		"description": "Industry Accelerator.",
  					"generator": "IndAcc-Projects",
  					"public": false,
					"tags": [
    						"string"
  						],
					"storage": {
				    		"type": "assetfiles",
				    		"guid": "d0e410a0-b358-42fc-b402-dba83316413b"
				 	 	}
					}'
				declare -a metadata="${METADATA}"

				http_proj=$(curl -s --write-out "%{http_code}\n" -X POST -k \
	  				"${CPD_HOST}/transactional/v2/projects" \
	  				"${curlArgs2[@]}" \
	  				-F file=@$project_zipfile \
	  				-F "$metadata" \
   	     					--output output.txt )
				echo "$TIMESTAMP">>$logfile
				
				if [[ $http_proj == 202 ]]
				then 
	        			cat output.txt>>$logfile
					guid=$(cat output.txt | grep -Po '"location":"\K[^"]*' | awk -F / '{print $4}')
				fi
				trans_id=$(cat output.txt | sed "s/{.*\"id\":\"\([^\"]*\).*}/\1/g")
				
	   		done
			  
			log_msg "INFO" "Project with this name created : $analytics_project" "$logfile"	
	
  		else 
			echo
   			log_msg "ERROR" "Aborting Import... failed to create $http_proj" "$logfile"
   			rm -rf output.txt
   			exit 0 
  		fi 

 	else
		echo
  		log_msg "ERROR" "Aborting Import... incorrect details/cluster unreachable. $HTTP_CODE " "$logfile"
  		rm -rf output.txt
  		exit 0 
 	fi
	
	echo
 	log_msg "SUCCESS" "Analytics project imported...." "$logfile"
 	
fi

#################################################################################################################################################
# Import glossary categories and terms and publish glossary
#################################################################################################################################################


if [[ $import_without_glossary != 1 ]]
then

	if [[ $script_exe_with_tar == 1 ]]
	then
		cat_path=$accelerator_name-industry-accelerator/$accelerator_name-glossary-categories.csv
		term_path=$accelerator_name-industry-accelerator/$accelerator_name-glossary-terms.csv
	else
		cat_path=$accelerator_name-glossary-categories.csv
		term_path=$accelerator_name-glossary-terms.csv
	fi
	
	if [[ `stat -c %s $cat_path` == 0 || `stat -c %s $term_path` == 0 ]]
	then
		log_msg "WARNING" "The glossary files are empty, import of categories and terms are skipped..." "$logfile"
		import_without_glossary=1
	fi
fi

if [[ $import_without_glossary != 1 ]]
then
	# WKC Glossary Import 
	echo
	log_msg "INFO" "Importing the $accelerator_name accelerator categories into Watson Knowledge Catalog..." "$logfile"
	
	http_cat=$(curl -s --write-out "%{http_code}\n" -X POST "${CPD_HOST}/v3/governance_artifact_types/all/import?merge_option=all" \
		-H "accept: application/json" \
		-H "Authorization: Bearer $token" \
  		-H "content-type: multipart/form-data" \
  		-F "file=@\"./$cat_path\";type=text/csv;charset=windows-1250" -k \
  		--output output.txt)

	echo "$TIMESTAMP">>$logfile
	cat output.txt>>$logfile

	if [[ $http_cat == 200 ]]
	then
		echo
 		if cat output.txt | grep -q "Line skipped, insufficient permission to modify category {0}"
		then 	
			log_msg "ERROR" "Line skipped, Pre-existing category present. Insufficient permissions to modify existing category." "$logfile"
			log_msg "ERROR" "Aborting category and glossary import." "$logfile"
			abort_glossary_import=1
			sleep 5
		else 
			abort_glossary_import=0
			log_msg "SUCCESS" "Category has been imported into Watson Knowledge Catalog..." "$logfile"
		fi
	
	elif [[ $http_cat == 401 ]] 
	then
		echo
	 	log_msg "ERROR" "The current user and does not have  permissions to manage Watson Knowledge Catalog.... $http_cat" "$logfile"
	 	rm -rf output.txt
	 	
	else
		echo
	 	log_msg "ERROR" "Import of categories into Watson Knowledge Catalog failed... $http_cat" "$logfile"
 		rm -rf output.txt
 		
	fi

	if [[ $abort_glossary_import == 0 ]]
	then 
		echo
		log_msg "INFO" "Importing the $accelerator_name accelerator business terms into Watson Knowledge Catalog..." "$logfile"

		http_term=$(curl -s --write-out "%{http_code}\n" -X POST "${CPD_HOST}/v3/governance_artifact_types/glossary_term/import?merge_option=all" \
			-H "accept: application/json" \
		  	-H "Authorization: Bearer $token" \
	  		-H "content-type: multipart/form-data" \
		  	-F "file=@\"./$term_path\";type=text/csv;charset=windows-1250" -k \
  			--output output.txt) 
	
		workflow_id=$(grep -oP '(?<="workflow_id": ")[^"]*' output.txt)
		process_id=$(grep -oP '(?<="process_id": ")[^"]*' output.txt)

		echo "$TIMESTAMP">>$logfile
		cat output.txt>>$logfile

		if [[ $http_term == 200 ]]
		then
			echo 
		 	log_msg "SUCCESS" "Business terms have been imported into Watson Knowledge Catalog..." "$logfile"

		elif [[ $http_term == 401 ]]
		then
			echo
			log_msg "ERROR" "The current user does not have permissions to manage Watson Knowledge Catalog... $http_term" "$logfile"
 			rm -rf output.txt
		 
		else
			echo
 			log_msg "ERROR" "Import of business terms into Watson Knowledge Catalog failed... $http_term" "$logfile"
 			rm -rf output.txt
		 	
		fi
	fi

	################# End of mandatory import section ############
	# Terms Publish section 
	
	if [[ $abort_glossary_import == 0 &&  $http_term == 200 ]]
	then
		echo
		log_msg "SUCCESS" "Category and business terms import completed successfully through Watson Knowledge Catalog." "$logfile"
	
		if [[ -z "$publish_glossary_terms" ]]
		then 
			echo
			log_msg "INFO" "Do you want to publish the glossary terms? (Note : Admin Privilege required for this)" "$logfile"
			echo "[INFO] In case of no response in 120 seconds publish of glossary terms will be skipped."
			read -t100 -p 'Enter choice as [Y/y] or [N/n]: ' publish_glossary_terms
			if [[ $? -gt 120 ]]
	       		then
                       		echo
	                	log_msg "WARNING" "No input entered by user... Skipping glossary terms publish step." "$logfile"
                	fi
		fi

		if [[ $publish_glossary_terms == 'Y' || $publish_glossary_terms == 'y' ]] 
		then
		
			echo
			log_msg "INFO" "Publishing Business Glossary...." "$logfile"


			action_id="#publish"
			final_status="#publish"
	
			while true
			do 
				draft_result=$(curl -s --write-out "%{http_code}\n" -k -X \
						GET -H "Authorization: Bearer $token" \
					"${CPD_HOST}/v3/workflows/$workflow_id?includeUserTasks=true" --output output.txt)

				echo "$TIMESTAMP">>$logfile
			        cat output.txt>>$logfile
			
				if [[ $draft_result == 200 ]]
				then 
			
					task_id=$(cat output.txt | grep -Po '"task_id":"\K[^"]*')
					
 					action_id=$(cat output.txt | grep -Po '"user_tasks":\[\K[^\]]*' \
								   | grep -Po '"entity":\K[^\]]*' \
								   | grep -Po '"form_properties":\K[^\]]*' \
								   | grep -Po '"enum_values":\K[^\]]*' \
								   | grep -Po '"id":"\K[^"]*' | head -n1)
						
					publish_glossary=$(curl -s --write-out "%{http_code}\n" -k -X POST -H "Authorization: Bearer $token" \
							   -H "Content-Type: application/json" \
							   --data '{"action":"complete","form_properties":[{"id":"action","value":"'$action_id'"}]}' \
							"${CPD_HOST}/v3/workflow_user_tasks/$task_id/actions" --output output.txt)

					echo "$TIMESTAMP">>$logfile
				        cat output.txt>>$logfile

					if [[ $publish_glossary == 204 || $publish_glossary == 202 ]]
					then
					
						if [[ "$final_status" = $action_id ]]
						then 	 
							break
						fi
					else 
						echo
						log_msg "ERROR" "Publish of business terms failed.... $publish_glossary" "$logfile"
						termspublish=0
						break
					fi 
				
				else
					echo
					log_msg "ERROR" "Publish of business terms failed.... $draft_result" "$logfile"
					termspublish=0
					break
				fi
			done
 
	
			rm -rf output.txt
			echo

			if [[ $publish_glossary == 204 || $publish_glossary == 202 ]]
			then
				log_msg "SUCCESS" "Business terms published successfully...." "$logfile"
				termspublish=1
			fi
			
		elif [[ $publish_glossary_terms == 'N' || $publish_glossary_terms == 'n' ]]
		then 
			log_msg "INFO" "Skipping publish of terms...." "$logfile"
			termspublish=0
			rm -rf output.txt
       
		else 
			echo
			log_msg "WARNING" "Skipping publish of terms step...." "$logfile"
			termspublish=0
           		rm -rf output.txt 
		fi 		
 
	fi
else 
	log_msg "WARNING" "Import & Publish of categories and business terms into Watson Knowledge Catalog skipped.." "$logfile"
	termspublish=0
fi

##################################################################################################################################
# Notebook Job Run section
##################################################################################################################################

echo

log_msg "INFO" "Checking if all artefacts and assets have been loaded..." "$logfile"

if [[ $skip_Project_Import == 1 ]]
then
	run_notebook_jobs='N'
	log_msg "INFO" "No notebook jobs found as this accelerator has no analytics project..." "$logfile"
fi 

sleep 15

if [[ -z "$run_notebook_jobs" ]]
then
	
	log_msg "INFO" "Do you wish to run the Notebook jobs in the project?" "$logfile"
        echo "[INFO] In case of no response in 120 seconds notebook jobs execution will be skipped."
	read -t100 -p 'Enter choice as [Y/y] or [N/n]: ' run_notebook_jobs
        if [[ $? -gt 120 ]]
        then
	        echo
                log_msg "WARNING" "No input entered by user... Skipping notebook job execution." "$logfile"
        fi
fi

# API TO CHECK IF JOB EXISTS

if [[ $run_notebook_jobs == 'Y' || $run_notebook_jobs == 'y' ]]
then
	log_msg "INFO" "Checking if notebook jobs exist in analytics project" "$logfile"

	job_exist=$(curl -s --write-out "%{http_code}\n" -X GET -k \
                         -H "Authorization: Bearer $token" \
                         -H "cache-control: no-cache" \
                         -H "content-type: application/json" \
                         -H "accept: */*" \
                   "${CPD_HOST}/v2/jobs?project_id=$guid" --output output.txt)
	
	echo "$TIMESTAMP">>$logfile
        cat output.txt>>$logfile
	cp output.txt notebook_jobs_info.txt 

	################ NOTEBOOK RUNS ###################
	run_all_notebook_jobs=0
	if [[ $job_exist == 200 ]]
	then
	
		jobs_count=$(cat notebook_jobs_info.txt | grep -Po '"name":"\K[^"]*' | wc -l)
				
		i=1
		
		while [[ $i -le $jobs_count ]]
		do 

			current_job=$(cat notebook_jobs_info.txt | grep -Po '"name":"\K[^"]*' | grep $i-*)
			echo
			notebook_exe=1
			log_msg "INFO" "$current_job Kicked Off...." "$logfile"
			
			current_asset_id=$(cat notebook_jobs_info.txt | sed 's/"name"/\n"name"/g' \
									      | grep "$current_job" | grep -Po '"asset_id":"\K[^"]*')
			

			job_start=$(curl -s --write-out "%{http_code}\n" -X POST \
				                 -k "${CPD_HOST}/v2/jobs/$current_asset_id/runs?project_id=$guid" \
		 				 -H "Authorization: Bearer $token" \
						 -H "content-type: application/json" \
						 -H "accept: */*" \
						 -H "cache-control: no-cache" \
		    				 -d '{"job_run":{}}' --output output.txt)

			echo "$TIMESTAMP">>$logfile
		        cat output.txt>>$logfile
				
			job_manager_id=$(cat output.txt | grep -Po '"job_manager_id":"\K[^"]*')
			timetaken=0	
		
			if [[ $job_start == 201 ]]
			then 
				log_msg "INFO" "Notebook job run in progress...." "$logfile"
				notebook_status="Running"
				while [[ $notebook_status != "Completed" ]]
				do
					sleep 15
					get_job_status=$(curl -s --write-out "%{http_code}\n" -X GET -k \
								  -H "Authorization: Bearer $token" \
								  -H "cache-control: no-cache" \
								  -H "content-type: application/json" \
								  -H "accept: */*" \
								"${CPD_HOST}/v2/jobs/$current_asset_id/runs?project_id=$guid" --output output.txt)
								
					echo "$TIMESTAMP">>$logfile
					cat output.txt>>$logfile
	
					if [[ $get_job_status != 200 ]]
					then 
						echo
						log_msg "ERROR" "Notebook job run failed..." "$logfile"
						break 2
					fi
					
					sleep 15 
					timetaken=$(($timetaken + 20 ))

					if [[ $get_job_status == 200 ]]
					then
						#echo $get_job_status
	
						notebook_status=$(cat output.txt | grep -Po '"state":"\K[^"]*')
						notebook_job_output=$(cat output.txt | grep -Po '"notebook_job_output":\K[^,]*')
	
						if [[ $notebook_status == "Running" && $notebook_job_output != "{}" ]]
						then	
							
							total_executed_cells=$(cat output.txt | grep -Po '"total_executed_cells":\K[^,}]*')
	                                        	total_cells=$(cat output.txt | grep -Po '"total_cells":\K[^,}]*')
        	                                	job_percent=$(printf %0.2f $(awk "BEGIN {print ( $total_executed_cells)/$total_cells * 100 }"))
							log_msg "INFO" "Notebook job run status : $notebook_status , Notebook job run completion : $job_percent %" "$logfile"
							
						fi					

						if [[ $notebook_status == "Failed" ]]
						then
							echo
							log_msg "ERROR" "Notebook job run failed... Please visit the $CPD_HOST cluster URL. Navigate to the respective $analytics_project project > Goto jobs and check the notebook job run for further information. " "$logfile"
							
							break 2
						fi
						
						if [[ $timetaken == 1000 ]]
						then
							echo
							log_msg "WARNING" "Notebook job runtime exceeding over 15 minutes... Please visit the $CPD_HOST cluster URL. Navigate to the respective $analytics_project project > Goto jobs and check the notebook job run for further information. " "$logfile"
							break 2
						fi
					fi			
		
				done

				if [[ $notebook_status == "Completed" ]]
				then
					log_msg "SUCCESS" "$current_job completed successfully..." $logfile
					
				fi
				
			else 
				echo
				notebook_exe=99
				log_msg "ERROR" "Notebook job run failed with status code : $job_start. Please visit the $CPD_HOST cluster URL. Navigate to the respective $analytics_project project > Goto jobs and check the notebook job run for further information " "$logfile"
			fi

			if [[ $i = 2 ]]
			then
				job_id=$current_asset_id				
				#echo $job_id
				run_id=$job_manager_id
				#echo $run_id
			fi
			i=$(($i + 1 ))
		done
		echo

		total_job_rows=$(cat notebook_jobs_info.txt | grep -Po '"total_rows":\K[^,}]*')

		if [[ $total_job_rows == 0 ]]
		then
			log_msg "WARNING" "Notebook jobs can't be run. Check if cluster has WML and verify analytics project assets. Visit Services catalog section on the $CPD_HOST cluster to check if WML is enabled and the Industry Accelerators link to download the project assets again." "$logfile"
		
		elif [[ $notebook_status == "Completed" ]]
		then
			log_msg "SUCCESS" "Notebook Job runs completed..." "$logfile"
			run_all_notebook_jobs=1
			
			
			version_date=$(date '+%Y-%m-%d')
		        shiny_deployment=$(curl -s --write-out "%{http_code}\n" -k -X GET -H "Authorization: Bearer $token" \
                                "$CPD_HOST/ml/v4/deployments?&version=$version_date" --output output.txt)

		        if [[ $shiny_deployment != 200 ]]
		        then
                		log_msg "ERROR" "Could not retrieve deployed dashboard details... Kindly visit the cluster in the below summary and check in the deployment section..." "$logfile"

		        elif [[ $shiny_deployment == 200 ]]
		        then

                		latest_timestamp=$(cat output.txt | grep -Po '"modified_at":\K[^,]*' | sort -k1 -r | head -1 | sed 's/"//g')
				id=$(cat output.txt | grep -B1 "\"modified_at\": \"`echo $latest_timestamp`\"" | grep "\"id\":" | sed 's/^ *//g')
               			space_id=`echo $id | grep -Po '"id":\K[^,]*' | sed 's/"//g'`
		                link=$(cat output.txt | grep -Po '"url":\K[^,]*' | sed 's/"//g' | grep $space_id)
		                dashboard_link="$CPD_HOST/ml/v4/deployments/"`echo $space_id`"/r_shiny"

	                	if [[ `echo $link` == `echo $dashboard_link` ]]
	       		        then
        		                echo "[INFO] Retrieving R-Shiny Dashboard link..."
                		else
		                        log_msg "WARNING" "Dashboard link not found... Kindly visit the cluster in the below summary and check in the deployment section..." "$logfile"
                		fi

    			fi
		
		else
			log_msg "WARNING" "Notebook job run not completed. Please visit the cluster given below, navigate to the imported project, then check the jobs tab for more details on the job status or to re-run...." "$logfile"
		fi

		rm -rf notebook_jobs_info.txt		
	
	else 
		log_msg "INFO"  "No notebook jobs found. Please visit the $CPD_HOST cluster URL. Navigate to the respective $analytics_project project... > Goto jobs and check the notebook job run for further information." "$logfile"
        fi
	
elif [[ $run_notebook_jobs == 'N' || $run_notebook_jobs == 'n' ]]
then
       	log_msg "INFO" "Skipping Notebook job runs...." "$logfile"

else
        log_msg "WARNING" "Skipping Notebook job runs..." "$logfile"
fi


################## END OF NOTEBOOK JOB SECTION #####################

rm -rf output.txt
echo
echo 
######################################################################################################################################
#			SUMMARY SECTION FOR IMPORT PROCESS
######################################################################################################################################

log_msg "INFO" "INDUSTRY ACCELERATOR IMPORT PROCESS SUMMARY" "$logfile"
echo

log_msg "INFO" "Host Cluster URL : $CPD_HOST" "$logfile"
log_msg "INFO" "Cloud Pak for Data username : $username" "$logfile"

if [[ $skip_Project_Import == 0 ]]
then 
	log_msg "INFO" "Imported analytics project name : $analytics_project" "$logfile"
fi

if [[ $abort_glossary_import == 0 ]]
then
	log_msg "INFO" "Categories and business glossary imported into Watson Knowledge Catalog." "$logfile"
fi

if [[ $termspublish == 1 ]]
then
	log_msg "INFO" "Business terms published into Watson Knowledge Catalog." "$logfile"
fi

if [[ $run_all_notebook_jobs == 1 && $notebook_status != "Failed" && $dashboard_link != "" && $notebook_exe != 99 ]]
then
	log_msg "INFO" "All notebook jobs have run successfully." "$logfile"
	log_msg "INFO" "Dashboard link : $dashboard_link" "$logfile"
fi

echo
echo "[INFO] : Please visit the Cloud Pak for Data cluster above to access all the imported artefacts. View "$logfile" to view the import process log."
echo
